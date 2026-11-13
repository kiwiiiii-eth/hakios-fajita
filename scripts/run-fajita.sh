#!/bin/bash
# 6T 一鍵測試：打包 → 讓手機回到 ABL fastboot → fastboot boot → 等 loader 回到 U-Boot → 讀回完整紀錄
#   run-fajita.sh [kernel] [ramdisk] [額外 boot-args]
#   環境變數：SECS（loader_return_after，預設 20）、UBOOT（預設 out/u-boot-r3.bin）、NAME（紀錄檔名）
# 全程只進 RAM；唯一的硬體寫入是 PMIC 重開原因（0x88f=0x04，使用者 11-10 同意），讓 U-Boot reset 後回 ABL fastboot。
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}; K=$ROOT/hakios-xnu-kernel
KERNEL=${1:-$K/hakios-kernel}; [ -f "$KERNEL" ] || KERNEL=$K/build/hakios-kernel-vt19
RAMDISK=${2:-$K/prebuilt/userland/hello}; EXTRA=${3:-}
UBOOT=${UBOOT:-$REPO/prebuilt/u-boot.bin}; SECS=${SECS:-20}
NAME=${NAME:-run-$(date +%m%d-%H%M%S)}; LOG=$ROOT/out/logs/$NAME.txt; mkdir -p "$ROOT/out/logs" "$K/build"
# ARGS and SOCARGS: the whole line, or only what the kernel's built-in arguments leave out (scripts/lib-args.sh); no run on a stale kernel
. "$REPO/scripts/lib-args.sh"; resolve_args "$K" "$KERNEL" || exit 1
CMDLINE="loader_return_after=$SECS -v $ARGS $SOCARGS$EXTRA"
echo "run: kernel=$(basename "$KERNEL") ramdisk=$(basename "$RAMDISK")"
echo "run: cmdline=$CMDLINE"
# DRYRUN_CMDLINE=1: say the command line and stop, before the phone, fastboot or USB are touched (the tests use only this)
if [ -n "${DRYRUN_CMDLINE:-}" ]; then exit 0; fi

cd "$K"
python3 xnuloader/mkpayload.py -o build/run.bin kernel="$KERNEL" ramdisk="$RAMDISK" --cmdline "$CMDLINE" >/dev/null
python3 tools/mkubootimg.py -d fajita -u "$UBOOT" -p build/run.bin -c build/run.hkub >/dev/null
"$REPO/scripts/pack-fajita.sh" "$UBOOT" build/run.hkub >/dev/null
IMG=$ROOT/out/hakios-u-boot-fajita.img

state() { fastboot devices 2>/dev/null | awk -v s="${ABL_SERIAL:-}" '$1 ~ /^\?+$/ {print "uboot"; exit} $2=="fastboot" && (s=="" || $1==s) {print "abl"; exit}'; }
case "$(state)" in
abl) ;;
uboot)
	echo "run: 手機在 U-Boot，寫重開原因並 reset 回 ABL fastboot"
	if timeout 8 fastboot oem run:"pmic dev pmic@0" >/dev/null 2>&1 &&
	   timeout 8 fastboot oem run:"pmic write 0x88f 0x04" >/dev/null 2>&1; then
		timeout 8 fastboot oem run:reset >/dev/null 2>&1 || true
	else
		pkill -f "fastboot oem run" 2>/dev/null || true
		echo "run: U-Boot 沒回應，請按住「電源＋音量上」約 10～15 秒進 fastboot（等 30 分鐘）"
	fi ;;
*) echo "run: 看不到手機，請按住「電源＋音量上」進 fastboot（等 30 分鐘）" ;;
esac
for i in $(seq 1 900); do [ "$(state)" = abl ] && break; sleep 2; done
[ "$(state)" = abl ] || { echo "run: 等不到 ABL fastboot"; exit 1; }

fastboot boot "$IMG" >/dev/null 2>&1; T0=$(date +%s); echo "run: 已開機 $(date +%T)，等 loader 回到 U-Boot"
sleep 8
for i in $(seq 1 $(( (SECS + 120) / 2 ))); do [ "$(state)" = uboot ] && break; sleep 2; done
[ "$(state)" = uboot ] || { echo "run: U-Boot 沒回來（可能整機當住），請拍螢幕"; exit 2; }
sleep 2
timeout 120 fastboot oem console 2>&1 | sed 's/^(bootloader) //' > "$LOG" || true
echo "run: $(( $(date +%s) - T0 )) 秒，紀錄 ${LOG}（$(wc -c < "$LOG") bytes）"
grep -E "^returned|^hung|^early-exception|^checkpoint|THE KERNEL HUNG|EARLY KERNEL EXCEPTION|^panic\(|Hello from user space" "$LOG" | head -8
