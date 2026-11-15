#!/bin/bash
# beta/install.sh, switch.sh and uninstall.sh run end to end against fake-fastboot.py: a 6T with Android in slot a and
# the developer phone's own partition table from before darwin (out/gpt-backup-20261115), through
#   install (darwin carved, userdata made again, the system image, dtbo_b from slot a, boot_b, slot b active)
#   -> switch to Android and back -> install again (an update: nothing erased) -> a refused table (another entry
#   changed) -> uninstall (the table as it was, -w, slot b as it was, slot a active)
# and the state checked after each. Nothing here touches a phone: fastboot is the fake, first in PATH.
#   scripts/test-install.sh [DIR]     DIR: the saved table (default $ROOT/out/gpt-backup-20261115)
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}; KREPO=$ROOT/hakios-xnu-kernel
SAVED=${1:-$ROOT/out/gpt-backup-20261115}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export FAKE=$T/phone GPTPLAN_DIR=$KREPO/tools
W=$T/work; mkdir -p "$FAKE/parts" "$T/bin" "$W/hakios-xnu-kernel/userland" "$W/hakios-xnu-kernel/xnuloader" \
	"$W/hakios-xnu-kernel/tools" "$W/hakios-fajita/scripts" "$W/out"
cc -O1 -Wall -Wextra -Werror -o "$FAKE/gpt-test" "$KREPO/tools/gpt-test.c"
cp "$SAVED/gpt-head.orig.bin" "$FAKE/head.bin"; cp "$SAVED/gpt-tail.orig.bin" "$FAKE/tail.bin"
: > "$FAKE/log.txt"
for p in boot_a boot_b; do printf 'ANDROID! the stock boot image of slot %s\n' "${p#boot_}" > "$FAKE/parts/$p.img"; done
printf 'dtbo of slot a (Android)\n' > "$FAKE/parts/dtbo_a.img"; printf 'dtbo of slot b (stale)\n' > "$FAKE/parts/dtbo_b.img"
printf 'vbmeta\n' > "$FAKE/parts/vbmeta_a.img"; cp "$FAKE/parts/vbmeta_a.img" "$FAKE/parts/vbmeta_b.img"
# partitions are whole: each file padded to 64 KB, as readpart gives a whole partition
for f in "$FAKE"/parts/*.img; do python3 -c "import sys; p=sys.argv[1]; b=open(p,'rb').read(); open(p,'wb').write(b+bytes(65536-len(b)))" "$f"; done
cp -R "$FAKE/parts" "$T/parts.orig"
python3 - <<EOF
import json; json.dump({'mode': 'abl', 'slot': 'a', 'abl_userdata': [1601344, 30437370], 'gpt_written': False,
    'resident': None, 'ramdisk': False}, open('$FAKE/state.json', 'w'))
EOF
printf '#!/bin/bash\nexec python3 %s "$@"\n' "$REPO/scripts/fake-fastboot.py" > "$T/bin/fastboot"
printf '#!/bin/bash\nexit 1\n' > "$T/bin/adb"
chmod +x "$T/bin/fastboot" "$T/bin/adb"
# the kit's work tree, in small: what install.sh reads, and a mk-installimg.sh that makes a marked image
head -c 3000000 /dev/zero > "$W/hakios-xnu-kernel/userland/system.apfs"
: > "$W/hakios-xnu-kernel/userland/root.apfs"
printf 'loader with oem gptwrite\n' > "$W/hakios-xnu-kernel/xnuloader/loader.efi"
cp "$KREPO/tools/gpt-plan.py" "$W/hakios-xnu-kernel/tools/"
: > "$W/out/hakios-fajita-usb.img"
cat > "$W/hakios-fajita/scripts/mk-installimg.sh" <<'EOF'
#!/bin/bash
# as the real one lies in a boot partition: U-Boot gzipped (no readable marker), the HKUB container, the XNUP payload
printf 'ANDROID!\x1f\x8b(gzipped U-Boot) HKUB XNUP rdsrc=darwin epoch=%s\n' "$(date +%s%N)" > "$HAKIOS_ROOT/out/hakios-fajita-install.img"
EOF
chmod +x "$W/hakios-fajita/scripts/mk-installimg.sh"
export PATH="$T/bin:$PATH" WORK=$W BACKUPS=$T/backups
B=$REPO/beta
st() { python3 -c "import json,sys; print(json.load(open('$FAKE/state.json')).get('$1'))"; }
check() { if eval "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; FAILED=1; fi; }
table() { python3 "$KREPO/tools/gpt-plan.py" info "$FAKE/head.bin" "$FAKE/tail.bin" | grep '^TABLE'; }
FAILED=

echo "== install (Android in slot a, no darwin)"
ERASE_ANDROID_DATA=yes "$B/install.sh" > "$T/out1.txt" 2>&1 || { cat "$T/out1.txt"; exit 1; }
check "darwin carved: 22048256..30437370" '[ "$(table | sed -n "s/.*darwin=\([^ ]*\).*/\1/p")" = 22048256..30437370 ]'
check "userdata made again once, at its new size" '[ "$(st wiped)" = 1 ] && [ "$(st wiped_userdata)" = "[1601344, 22048255]" ]'
check "the system image written once" '[ "$(st darwinput)" = 1 ]'
check "slot b active, HakiOS in boot_b" '[ "$(st slot)" = b ] && grep -a -q "HKUB" "$FAKE/parts/boot_b.img"'
check "dtbo_b now slot a's" 'cmp -s "$FAKE/parts/dtbo_b.img" "$FAKE/parts/dtbo_a.img"'
check "slot a untouched" 'cmp -s "$FAKE/parts/boot_a.img" "$T/parts.orig/boot_a.img" && cmp -s "$FAKE/parts/dtbo_a.img" "$T/parts.orig/dtbo_a.img"'
check "the backup: the table before, stock boot_b" 'cmp -s "$BACKUPS/b1289b47/gpt-head.bin" "$SAVED/gpt-head.orig.bin" && cmp -s "$BACKUPS/b1289b47/boot_b.img" "$T/parts.orig/boot_b.img"'
check "the phone booted iOS" '[ "$(st mode)" = ios ]'

echo "== switch android, then hakios"
st_set() { python3 - "$@" <<EOF
import json; s=json.load(open('$FAKE/state.json')); s['mode']='abl'; json.dump(s, open('$FAKE/state.json','w'))
EOF
}
st_set; "$B/switch.sh" android > "$T/out2.txt" 2>&1 || { cat "$T/out2.txt"; exit 1; }
check "Android's slot a active, Android booted" '[ "$(st slot)" = a ] && [ "$(st mode)" = android ]'
st_set; "$B/switch.sh" hakios > "$T/out3.txt" 2>&1 || { cat "$T/out3.txt"; exit 1; }
check "slot b active, iOS booted" '[ "$(st slot)" = b ] && [ "$(st mode)" = ios ]'

echo "== install again (an update)"
st_set; "$B/install.sh" > "$T/out4.txt" 2>&1 < /dev/null || { cat "$T/out4.txt"; exit 1; }
check "nothing erased, no question asked" '[ "$(st wiped)" = 1 ] && grep -q "darwin is there already" "$T/out4.txt"'
check "the system image written again, into slot b" '[ "$(st darwinput)" = 2 ] && [ "$(st slot)" = b ]'
check "the backup kept as it was" 'cmp -s "$BACKUPS/b1289b47/boot_b.img" "$T/parts.orig/boot_b.img"'
check "the update went into slot b, Android's boot_a untouched" 'grep -q "goes into slot b" "$T/out4.txt" && cmp -s "$FAKE/parts/boot_a.img" "$T/parts.orig/boot_a.img"'

echo "== install again from another Mac (no backup there): HakiOS found in boot_b"
st_set; BACKUPS=$T/backups2 "$B/install.sh" > "$T/out4b.txt" 2>&1 < /dev/null || { cat "$T/out4b.txt"; exit 1; }
check "found in slot b and updated there; boot_a untouched" 'grep -q "HakiOS in: b" "$T/out4b.txt" && grep -q "goes into slot b" "$T/out4b.txt" && cmp -s "$FAKE/parts/boot_a.img" "$T/parts.orig/boot_a.img"'
check "that backup says boot_b is HakiOS's, not the phone's own" 'grep -q "boot_b=hakios" "$T/backups2/b1289b47/info.txt"'

echo "== a table the loader must refuse"
st_set; python3 - <<EOF
import json; s=json.load(open('$FAKE/state.json')); s['mode']='loader'; s['ramdisk']=True; json.dump(s, open('$FAKE/state.json','w'))
EOF
python3 - "$FAKE" <<'EOF'
import sys, struct, os
sys.path.insert(0, os.environ['GPTPLAN_DIR'])
import importlib.util
spec = importlib.util.spec_from_file_location('gp', os.path.join(os.environ['GPTPLAN_DIR'], 'gpt-plan.py')); gp = importlib.util.module_from_spec(spec); spec.loader.exec_module(gp)
f = sys.argv[1]; head = open(f + '/head.bin', 'rb').read(); h = head[4096:8192]; e = bytearray(head[2 * 4096:3 * 4096])
struct.pack_into('<Q', e, 15 * 128 + 40, gp.u64(e, 15 * 128 + 40) - 1)     # odm_b one block shorter
open(f + '/bad.stg', 'wb').write(gp.staged_of(gp.seal(h, bytes(e)), bytes(e)))
EOF
before=$(shasum "$FAKE/head.bin" "$FAKE/tail.bin")
fastboot stage "$FAKE/bad.stg" >/dev/null 2>&1
fastboot oem gptwrite > "$T/out5.txt" 2>&1 && R=0 || R=$?
check "refused, nothing written" '[ $R -ne 0 ] && grep -q "other than userdata" "$T/out5.txt" && [ "$before" = "$(shasum "$FAKE/head.bin" "$FAKE/tail.bin")" ]'
fastboot reboot >/dev/null 2>&1

echo "== uninstall"
REMOVE=yes "$B/uninstall.sh" > "$T/out6.txt" 2>&1 || { cat "$T/out6.txt"; exit 1; }
check "the table as it was (both copies)" 'cmp -s "$FAKE/head.bin" "$SAVED/gpt-head.orig.bin" && cmp -s "$FAKE/tail.bin" "$SAVED/gpt-tail.orig.bin"'
check "userdata made again at its whole size" '[ "$(st wiped)" = 2 ] && [ "$(st wiped_userdata)" = "[1601344, 30437370]" ]'
check "slot b as it was, slot a active, Android booted" '( for p in boot_b dtbo_b vbmeta_b; do cmp -s "$FAKE/parts/$p.img" "$T/parts.orig/$p.img" || exit 1; done ) && [ "$(st slot)" = a ] && [ "$(st mode)" = android ]'
check "every fastboot write after a gptwrite came after a restart" '! awk "/gptwrite/{w=1} /: (boot|reboot)/{w=0} w && /oem (darwinput|readpart|darwininfo)/{bad=1} END{exit !bad}" "$FAKE/calls.txt"'
st_flag() { python3 - "$1" "$2" <<EOF
import json, sys; s=json.load(open('$FAKE/state.json')); s['mode']='abl'; s[sys.argv[1]]=json.loads(sys.argv[2]); json.dump(s, open('$FAKE/state.json','w'))
EOF
}
same_copies() { python3 "$KREPO/tools/gpt-plan.py" info "$FAKE/head.bin" "$FAKE/tail.bin" | grep -q "^primary: checks; backup: checks; the same;"; }

echo "== install cut short: the table half written, then fastboot -w failing"
st_flag fail_backup_write true; st_flag fail_wipe 1
ERASE_ANDROID_DATA=yes "$B/install.sh" > "$T/out7.txt" 2>&1 && R=0 || R=$?
check "stopped; the primary new, the backup old" '[ $R -ne 0 ] && ! same_copies && table | grep -q "darwin=22048256"'
st_flag mode '"abl"'
ERASE_ANDROID_DATA=yes "$B/install.sh" > "$T/out8.txt" 2>&1 && R=0 || R=$?
check "run again: mended, then stopped at the failing -w (wipe-pending kept)" '[ $R -ne 0 ] && same_copies && grep -q "making them one" "$T/out8.txt" && [ -f "$BACKUPS/b1289b47/wipe-pending" ]'
st_flag mode '"abl"'
ERASE_ANDROID_DATA=yes "$B/install.sh" > "$T/out9.txt" 2>&1 || { cat "$T/out9.txt"; exit 1; }
check "run again: userdata made again at its new size, and the install done" 'grep -q "last run stopped" "$T/out9.txt" && [ "$(st wiped_userdata)" = "[1601344, 22048255]" ] && [ ! -f "$BACKUPS/b1289b47/wipe-pending" ] && [ "$(st slot)" = b ] && [ "$(st mode)" = ios ]'

echo "== uninstall cut short: the table half put back"
st_flag fail_backup_write true
REMOVE=yes "$B/uninstall.sh" > "$T/out10.txt" 2>&1 && R=0 || R=$?
check "stopped, the copies differ" '[ $R -ne 0 ] && ! same_copies'
w=$(st wiped); st_flag mode '"abl"'
REMOVE=yes "$B/uninstall.sh" > "$T/out11.txt" 2>&1 || { cat "$T/out11.txt"; exit 1; }
check "run again: mended, userdata made again, the table as it was" 'cmp -s "$FAKE/head.bin" "$SAVED/gpt-head.orig.bin" && cmp -s "$FAKE/tail.bin" "$SAVED/gpt-tail.orig.bin" && [ "$(st wiped)" = $((w + 1)) ] && [ ! -f "$BACKUPS/b1289b47/unwipe-pending" ] && [ "$(st slot)" = a ]'

echo "== Android updated into HakiOS's old slot: install refuses"
st_flag slot '"b"'; before=$(shasum "$FAKE/parts/boot_b.img")
"$B/install.sh" > "$T/out12.txt" 2>&1 < /dev/null && R=0 || R=$?
check "refused, boot_b (Android) untouched" '[ $R -ne 0 ] && grep -q "holds no HakiOS" "$T/out12.txt" && [ "$before" = "$(shasum "$FAKE/parts/boot_b.img")" ]'

echo "== as the refusal says: TARGET=a, then an ordinary update, switching, uninstalling"
st_flag mode '"abl"'
TARGET=a ERASE_ANDROID_DATA=yes "$B/install.sh" > "$T/out13.txt" 2>&1 < /dev/null || { cat "$T/out13.txt"; exit 1; }
check "HakiOS into slot a, remembered; Android's boot_b untouched" '[ "$(st slot)" = a ] && [ "$(cat "$BACKUPS/b1289b47/slot")" = a ] && [ "$before" = "$(shasum "$FAKE/parts/boot_b.img")" ]'
st_flag mode '"abl"'
"$B/install.sh" > "$T/out14.txt" 2>&1 < /dev/null || { cat "$T/out14.txt"; exit 1; }
check "an ordinary update goes into slot a; boot_b untouched" 'grep -q "goes into slot a" "$T/out14.txt" && [ "$before" = "$(shasum "$FAKE/parts/boot_b.img")" ]'
st_flag mode '"abl"'; "$B/switch.sh" android > "$T/out15.txt" 2>&1 || { cat "$T/out15.txt"; exit 1; }
check "switch.sh android makes slot b (Android's now) active" '[ "$(st slot)" = b ]'
st_flag mode '"abl"'; REMOVE=yes KEEP_DARWIN=1 "$B/uninstall.sh" > "$T/out16.txt" 2>&1 || { cat "$T/out16.txt"; exit 1; }
check "uninstall puts slot a back as it was before the first install, slot b active, boot_b untouched" 'cmp -s "$FAKE/parts/boot_a.img" "$T/parts.orig/boot_a.img" && [ "$(st slot)" = b ] && [ "$before" = "$(shasum "$FAKE/parts/boot_b.img")" ]'

[ -z "$FAILED" ] && echo "all as expected" || { echo "SOME FAILED (calls: $FAKE/calls.txt)"; trap - EXIT; exit 1; }
