#!/usr/bin/env python3
"""fake-fastboot.py: a OnePlus 6T as beta/install.sh, uninstall.sh and switch.sh see it through fastboot -- ABL and the
HakiOS loader -- kept in files under $FAKE, so that the scripts' every path is run on a Mac with no phone
(scripts/test-install.sh). The partition table is a real one (8-block dumps of LUN 0's ends), and the loader's
gptcheck/gptwrite decide with the loader's own code (tools/gpt-test.c, built as $FAKE/gpt-test); what is written is
written the way the loader writes it (the primary, then a backup made from it).

$FAKE/state.json  mode (abl, loader, ios, android), slot, the table as ABL saw it when it started, what is staged
$FAKE/head.bin, tail.bin   the unit's first and last 8 blocks
$FAKE/parts/NAME.img       the partitions read and flashed (boot_a ... vbmeta_b)
$FAKE/calls.txt            every call, for the test to look at
"""
import json
import os
import shutil
import struct
import subprocess
import sys
import time

FAKE = os.environ['FAKE']
sys.path.insert(0, os.environ['GPTPLAN_DIR'])
import importlib.util  # noqa: E402
spec = importlib.util.spec_from_file_location('gp', os.path.join(os.environ['GPTPLAN_DIR'], 'gpt-plan.py'))
gp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gp)
BS = 4096
SERIAL = 'b1289b47'


def load():
    return json.load(open(os.path.join(FAKE, 'state.json')))


def save(s):
    json.dump(s, open(os.path.join(FAKE, 'state.json'), 'w'), indent=1)


def path(n):
    return os.path.join(FAKE, n)


def okay(*info):
    for i in info:
        print(f'(bootloader) {i}', file=sys.stderr)
    print('OKAY [  0.001s]\nFinished. Total time: 0.001s', file=sys.stderr)
    return 0


def fail(why):
    print(f"FAILED (remote: '{why}')\nfastboot: error: Command failed", file=sys.stderr)
    return 1


def table(head, tail):
    ph, pe, p_ok, bh, be, b_ok, disk = gp.copies(head, tail)
    h, e = (ph, pe) if p_ok else (bh, be)
    ud, dw = gp.index_of(h, e, 'userdata'), gp.index_of(h, e, 'darwin')
    return gp.rng(gp.entry(h, e, ud)), (gp.rng(gp.entry(h, e, dw)) if dw >= 0 else None), disk


def main(a):
    s = load()
    open(path('calls.txt'), 'a').write(f'{s["mode"]}: {" ".join(a)}\n')
    if a == ['devices']:
        if s['mode'] == 'abl':
            print(f'{SERIAL}\tfastboot')
        elif s['mode'] == 'loader':
            print('xnuloader\tfastboot')
        return 0
    if s['mode'] not in ('abl', 'loader'):
        print('< waiting for any device >', file=sys.stderr)
        time.sleep(30)
        return 1
    head, tail = open(path('head.bin'), 'rb').read(), open(path('tail.bin'), 'rb').read()
    cmd = a[0]
    if cmd == 'getvar':
        if s['mode'] == 'loader':
            v = {'version': '0.5', 'product': 'xnuloader'}.get(a[1], '')
        else:
            ud = s['abl_userdata']
            v = {'unlocked': 'yes', 'current-slot': s['slot'], 'partition-type:userdata': 'f2fs',
                 'partition-size:userdata': hex((ud[1] - ud[0] + 1) * BS)}.get(a[1], '')
        print(f'{a[1]}: {v}\nFinished. Total time: 0.001s', file=sys.stderr)
        return 0
    if cmd == 'reboot':
        if s['mode'] == 'loader':
            s['mode'] = 'abl'          # the USB image's U-Boot set the reboot reason: back to ABL
            s['abl_userdata'] = table(head, tail)[0]
        else:
            s['mode'] = 'ios' if s['slot'] == s.get('hakios_slot') else 'android'
            s['booted'] = s['slot']
        save(s)
        return okay()
    if s['mode'] == 'abl':
        if cmd == 'boot':
            s.update(mode='loader', gpt_written=False, resident=None, staged=None, ramdisk=False,
                     uefi_darwin=table(head, tail)[1] is not None)
            save(s)
            return okay()
        if cmd == 'flash':
            # a partition is larger than what is flashed into it: what lay past the image stays (as on the phone)
            new, dst = open(a[2], 'rb').read(), path(f'parts/{a[1]}.img')
            old = open(dst, 'rb').read() if os.path.exists(dst) else b''
            old = old + bytes(max(0, 65536 - len(old)))
            open(dst, 'wb').write(new + old[len(new):])
            if a[1].startswith('boot_') and gp_marker(a[2]):
                s['hakios_slot'] = a[1][-1]
            save(s)
            print(f"Sending '{a[1]}' OKAY\nWriting '{a[1]}' OKAY\nFinished.", file=sys.stderr)
            return 0
        if cmd == 'set_active':
            s['slot'] = a[1]
            save(s)
            return okay()
        if cmd == '-w':
            s['wiped'] = s.get('wiped', 0) + 1
            s['wiped_userdata'] = s['abl_userdata']
            save(s)
            print("Erasing 'userdata' OKAY\nSending 'userdata' (1000 KB) OKAY\nWriting 'userdata' OKAY\n"
                  "Erasing 'metadata' OKAY\nFinished.", file=sys.stderr)
            return 0
        return fail('unknown command')
    # the loader
    if cmd == 'stage':
        if not s['ramdisk']:
            return fail('not staged to the resident area')
        shutil.copy(a[1], path('resident.bin'))
        s['resident'] = os.path.getsize(a[1])
        s['ramdisk'] = False
        save(s)
        return okay()
    if cmd == 'get_staged':
        shutil.copy(path('staged.bin'), a[1])
        return okay()
    if cmd != 'oem':
        return fail('unknown command')
    o = a[1:]
    if s['gpt_written'] and o[0] in ('darwinput', 'darwininfo', 'readpart', 'slotok', 'run'):
        return fail('the partition table was written: restart first')
    if o[0] == 'ramdisk':
        s['ramdisk'] = True
        save(s)
        return okay()
    if o[0] == 'gptinfo':
        ud, dw, disk = table(head, tail)
        return okay(f'userdata {ud[0]}..{ud[1]} darwin ' + (f'{dw[0]}..{dw[1]}' if dw else 'none'),
                    f'unit 0 blocks {disk}')
    if o[0] == 'readunit':
        lba, n = int(o[2]), int(o[3])
        _, _, disk = table(head, tail)
        if s['resident']:
            return fail('a root image is in the resident area')
        blob = head if lba == 0 else tail if lba == disk - 8 else None
        if blob is None or n != 8:
            return fail('this fake keeps the first and last 8 blocks only')
        open(path('staged.bin'), 'wb').write(blob)
        return okay()
    if o[0] == 'readpart':
        if s['resident']:
            return fail('a root image is in the resident area')
        shutil.copy(path(f'parts/{o[1]}.img'), path('staged.bin'))
        return okay()
    if o[0] == 'log':
        shutil.copy(path('log.txt'), path('staged.bin'))
        return okay()
    if o[0] in ('gptcheck', 'gptwrite'):
        if not s['resident']:
            return fail('no table staged (oem ramdisk, then its download)')
        r = subprocess.run([path('gpt-test'), path('head.bin'), path('tail.bin'), path('resident.bin')],
                           capture_output=True, text=True)
        open(path('log.txt'), 'w').write(r.stdout)
        if r.returncode != 0:
            return fail(r.stdout.strip().split(': ', 1)[-1][:60])
        if o[0] == 'gptcheck' or 'same=1' in r.stdout:
            return okay('allowed')
        st = open(path('resident.bin'), 'rb').read()
        nh, ne = st[:BS], st[BS:]
        _, _, disk = table(head, tail)
        h2 = bytearray(head)
        h2[BS:2 * BS] = nh
        el = gp.u64(nh, 72)
        h2[el * BS:el * BS + len(ne)] = ne
        bh = tail[7 * BS:]
        be_lba = gp.u64(bh, 72) if gp.header_checks(bh) else disk - 1 - len(ne) // BS
        b = bytearray(nh)
        struct.pack_into('<QQ', b, 24, disk - 1, 1)
        struct.pack_into('<Q', b, 72, be_lba)
        b = gp.seal(bytes(b), ne)
        t2 = bytearray(tail)
        t2[(be_lba - (disk - 8)) * BS:(be_lba - (disk - 8)) * BS + len(ne)] = ne
        t2[7 * BS:] = b
        open(path('head.bin'), 'wb').write(bytes(h2))
        open(path('tail.bin'), 'wb').write(bytes(t2))
        s['gpt_written'] = True
        s['resident'] = None
        save(s)
        return okay('written, both copies read back: restart the phone now')
    if o[0] == 'darwininfo':
        return okay() if s['uefi_darwin'] else fail("no darwin of the port's")
    if o[0] == 'darwinput':
        if not s['uefi_darwin']:
            return fail("no darwin of the port's")
        if not s['resident']:
            return fail('no root image staged')
        open(path('log.txt'), 'w').write(f'sysimg: {s["resident"]} bytes written and read back in 1 ms\n')
        s['darwinput'] = s.get('darwinput', 0) + 1
        save(s)
        return okay()
    return fail('unknown command')


def gp_marker(f):
    b = open(f, 'rb').read()
    return b'HKUB' in b and b'XNUP' in b


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
