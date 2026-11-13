#!/bin/bash
# Build the boot image that run-darwin.sh boots: U-Boot + the HakiOS loader with its own USB (xnuloader),
# packed for the 6T's ABL (`fastboot boot`). Nothing is flashed.
#   mk-usbimg.sh [u-boot.bin]   → $ROOT/out/hakios-fajita-usb.img
# Needs the loader built first: (cd hakios-xnu-kernel && xnuloader/mkidentity.sh && xnuloader/build.sh)
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}; K=$ROOT/hakios-xnu-kernel
UB=${1:-$REPO/prebuilt/u-boot.bin}
[ -f "$K/xnuloader/loader.efi" ] || { echo "no $K/xnuloader/loader.efi: build the loader first"; exit 1; }
mkdir -p "$K/build" "$ROOT/out"
cd "$K"
python3 xnuloader/mkpayload.py -o build/usb-payload.bin loader.efi=xnuloader/loader.efi --usb >/dev/null
python3 tools/mkubootimg.py -d fajita -u "$UB" -p build/usb-payload.bin -c build/usb.hkub >/dev/null
"$REPO/scripts/pack-fajita.sh" "$UB" build/usb.hkub >/dev/null
mv "$ROOT/out/hakios-u-boot-fajita.img" "$ROOT/out/hakios-fajita-usb.img"
ls -la "$ROOT/out/hakios-fajita-usb.img"
