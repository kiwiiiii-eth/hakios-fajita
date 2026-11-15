#!/bin/bash
# The cameras' module files (com.qti.sensormodule.*.bin: the sensors' register tables, drivers/camera/hakios.camera845.c)
# out of the phone's vendor partition, read through the HakiOS loader: for a phone whose Android does not start any more
# (pull-firmware.sh takes them from a running Android over adb). Nothing is written to the phone: the loader is booted
# over USB (fastboot boot), each unit's GPT is read to find vendor_<slot>, the partition is read in 64 MB pieces (oem
# readunit, staged and fetched one at a time), and the files are taken out of its ext4 on the Mac with e2fsprogs's
# debugfs (brew install e2fsprogs).
#   scripts/pull-camera-modules.sh [a|b]       (default b) -> hakios-xnu-kernel/fw-camera/
# USBIMG=... for another loader image (default: out/hakios-fajita-usb.img beside the two repositories).
set -euo pipefail
ME=pull-camera-modules.sh
HERE=$(cd "$(dirname "$0")/.." && pwd)
KIT=$HERE/beta
WORK=${WORK:-$(dirname "$HERE")}
# shellcheck source=../beta/lib-install.sh
. "$HERE/beta/lib-install.sh"
SLOT=${1:-b}
case "$SLOT" in a|b) ;; *) die "usage: $ME [a|b]" ;; esac
DEBUGFS=$(command -v debugfs || true)
[ -n "$DEBUGFS" ] || DEBUGFS="$(brew --prefix e2fsprogs 2>/dev/null)/sbin/debugfs"
[ -x "$DEBUGFS" ] || die "no debugfs: brew install e2fsprogs"
OUT=$K/fw-camera
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
PIECE=16384                     # blocks of 4096: 64 MB, what the loader's window and macOS's USB take in one go

to_loader
# which unit holds vendor_<slot>, and where: every unit's GPT (its first 8 blocks hold the header and up to 96 entries)
found=
for unit in 0 1 2 3 4 5; do
	fbq oem readunit "$unit" 0 8 >/dev/null || continue
	fb get_staged "$T/gpt$unit.bin" >/dev/null || die "reading unit $unit's table back failed"
	range=$(python3 - "$T/gpt$unit.bin" "vendor_$SLOT" <<'PYEOF'
import struct, sys
d = open(sys.argv[1], 'rb').read()
for bs in (4096, 512):
    if d[bs:bs + 8] != b'EFI PART':
        continue
    entries, count, size = struct.unpack_from('<QII', d, bs + 72)
    for i in range(count):
        at = entries * bs + i * size
        if at + size > len(d):
            break
        first, last = struct.unpack_from('<QQ', d, at + 32)
        name = d[at + 56:at + 128].decode('utf-16-le', 'replace').split('\0')[0]
        if name == sys.argv[2]:
            print(first, last)
            sys.exit(0)
PYEOF
) || true
	if [ -n "$range" ]; then
		found="$unit $range"
		break
	fi
done
[ -n "$found" ] || die "no vendor_$SLOT in the phone's tables"
read -r UNIT FIRST LAST <<<"$found"
say "vendor_$SLOT: unit $UNIT, blocks $FIRST..$LAST ($(( (LAST - FIRST + 1) * 4096 >> 20 )) MB), read in pieces of $((PIECE * 4096 >> 20)) MB"
: > "$T/vendor.img"
for ((at = FIRST; at <= LAST; at += PIECE)); do
	n=$PIECE
	[ $((at + n - 1)) -le "$LAST" ] || n=$((LAST - at + 1))
	fbq oem readunit "$UNIT" "$at" "$n" >/dev/null || die "oem readunit $UNIT $at $n: $FB_OUT"
	fb get_staged "$T/piece.bin" >/dev/null || die "reading blocks $at.. back failed"
	cat "$T/piece.bin" >> "$T/vendor.img"
	printf '.'
done
echo
[ "$(dd if="$T/vendor.img" bs=1 skip=1080 count=2 2>/dev/null | xxd -p)" = 53ef ] || die "vendor_$SLOT is not an ext4 file system"
mkdir -p "$T/camera"
for dir in /lib64/camera /lib/camera; do
	for f in $("$DEBUGFS" -R "ls -p $dir" "$T/vendor.img" 2>/dev/null | awk -F/ '$6 ~ /^com\.qti\.(sensormodule\..*|tuned\.[a-z]+_[a-z0-9]+)\.bin$/ {print $6}'); do
		"$DEBUGFS" -R "dump $dir/$f $T/camera/$f" "$T/vendor.img" >/dev/null 2>&1 || true
	done
done
ls "$T"/camera/com.qti.sensormodule.*.bin >/dev/null 2>&1 || die "no com.qti.sensormodule.*.bin in vendor_$SLOT's /lib*/camera"
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$T"/camera/com.qti.sensormodule.*.bin "$OUT/"
cp "$T"/camera/com.qti.tuned.*.bin "$OUT/" 2>/dev/null || true       # (the colour tuning: tools/camtuning.py)
for f in "$OUT"/*.bin; do
	python3 "$K/tools/camsensor.py" "$f" - 2>&1 | head -1
done
say "fw-camera: $(ls "$OUT" | wc -l | tr -d ' ') module files from vendor_$SLOT (the phone stays in the loader: fastboot reboot, or ./switch.sh)"
