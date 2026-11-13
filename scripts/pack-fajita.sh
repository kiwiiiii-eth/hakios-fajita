#!/bin/bash
# 在 Mac 上執行：把 u-boot.bin 包成 6T 的 ABL 吃得下的 boot image（參數與 ios-fajita shim 已實機驗證的一致）
#   pack-fajita.sh u-boot.bin [container.hkub]   → out/hakios-u-boot-fajita.img
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}
UB=${1:?usage: pack-fajita.sh u-boot.bin [container.hkub]}
DTB=${DTB:-$REPO/prebuilt/device-tree.dtb}
MKBOOTIMG=${MKBOOTIMG:-$REPO/prebuilt/mkbootimg.py}
OUT=$ROOT/out; mkdir -p "$OUT"
[ "$(dd if="$UB" bs=1 skip=56 count=4 2>/dev/null | xxd -p)" = 41524d64 ] || { echo "u-boot.bin 沒有 ARM64 Linux 標頭"; exit 1; }
gzip -9 -n -c "$UB" > "$OUT/u-boot.bin.gz"
cat "$OUT/u-boot.bin.gz" "$DTB" > "$OUT/u-boot.gz-dtb"
if [ -n "${2:-}" ]; then cp "$2" "$OUT/ramdisk.bin"
else (cd "$OUT" && rm -rf rd && mkdir rd && cd rd && find . | cpio -o -H newc --quiet | gzip -9 > ../ramdisk.bin); fi
python3 "$MKBOOTIMG" --header_version 1 --kernel "$OUT/u-boot.gz-dtb" --ramdisk "$OUT/ramdisk.bin" \
	--base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --pagesize 4096 \
	--os_version 17.0.0 --os_patch_level 2035-06 --cmdline "console=null" -o "$OUT/hakios-u-boot-fajita.img"
ls -la "$OUT/hakios-u-boot-fajita.img"
