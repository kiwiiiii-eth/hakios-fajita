#!/bin/bash
# 6T：透過 loader 自己的 USB 跑一輪（live 版：執行中每約 3 秒把即時紀錄抓到 $LOG.live）（官方 xl run 的流程），可先把 iOS 系統映像送進手機記憶體
#   run-darwin.sh [system.apfs|none] [root.apfs 或其他小 ramdisk] [額外 boot-args]
#   環境變數：SECS（loader_return_after，預設 60）、NAME（紀錄檔名）、KERNEL
# 全程只進 RAM。手機狀態自動處理：U-Boot → PMIC 重開原因＋reset → ABL → fastboot boot USB 版 loader → 等 xnuloader。
# 同一個 loader 跑過一次核心就不能再跑（官方說明），所以每輪都重新進 loader（U-Boot r4 會先寫重開原因，reset 一定回 ABL）。
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}; K=$ROOT/hakios-xnu-kernel
SYS=${1:-$K/userland/system.apfs}; RD=${2:-$K/userland/root.apfs}; EXTRA=${3:-}
KERNEL=${KERNEL:-$K/hakios-kernel}; SECS=${SECS:-60}
NAME=${NAME:-darwin-$(date +%m%d-%H%M%S)}; LOG=$ROOT/out/logs/$NAME.txt; mkdir -p "$ROOT/out/logs" "$K/build"
USBIMG=${USBIMG:-$ROOT/out/hakios-fajita-usb.img}
ARGS=$(cd "$K" && python3 tools/hakios-config.py args)
SOCARGS=$(grep -v '^[[:space:]]*#' "$K/devices/fajita/soc.args" | tr '\n' ' ' | tr -s ' ')
# VERBOSE=-v：核心文字畫在螢幕上（除錯用）；預設不畫，iOS 畫面乾淨，紀錄照樣交回
# PRE="name=value ..."：放在設定值前面的開機參數（注意：XNU 重複的參數以「最後一個」為準，要蓋掉設定值請放在最後的額外參數裡）
CMDLINE="loader_return_after=$SECS epoch=$(date +%s) sb_delay=8 ${VERBOSE:-} ${PRE:-} $ARGS $SOCARGS$EXTRA"
echo "darwin: kernel=$(basename "$KERNEL") system=$(basename "$SYS") ramdisk=$(basename "$RD")"
echo "darwin: cmdline=$CMDLINE"

state() { fastboot devices 2>/dev/null | awk -v s="${ABL_SERIAL:-}" '$1=="xnuloader"{print "loader"; exit} $1 ~ /^\?+$/ {print "uboot"; exit} $2=="fastboot" && (s=="" || $1==s) {print "abl"; exit}'; }
wait_for() { local want=$1 n=${2:-120}; for i in $(seq 1 $n); do [ "$(state)" = "$want" ] && return 0; sleep 1; done; return 1; }

# 1. 一個新的 loader（跑過核心的 loader 不能再用）
case "$(state)" in
loader) if [ -n "$FRESH" ]; then echo "darwin: 用現在這個還沒跑過的 loader（FRESH=1）"; else echo "darwin: loader 已跑過：reboot（會回 ABL）"; timeout 10 fastboot reboot >/dev/null 2>&1 || true; fi ;;
uboot)
	timeout 8 fastboot oem run:"pmic dev pmic@0" >/dev/null 2>&1 && timeout 8 fastboot oem run:"pmic write 0x88f 0x04" >/dev/null 2>&1 &&
		{ timeout 8 fastboot oem run:reset >/dev/null 2>&1 || true; } ||
		{ pkill -f "fastboot oem run" 2>/dev/null || true; echo "darwin: U-Boot 沒回應，請按住「電源＋音量上」進 fastboot"; } ;;
abl) ;;
*) echo "darwin: 看不到手機，請按住「電源＋音量上」進 fastboot" ;;
esac
if [ -z "$FRESH" ] || [ "$(state)" != loader ]; then
	wait_for abl 1800 || { echo "darwin: 等不到 ABL fastboot"; exit 1; }
	fastboot boot "$USBIMG" >/dev/null 2>&1
	echo "darwin: loader 開機中 $(date +%T)，等 USB（macOS 列舉約 1 分鐘）"
	wait_for loader 240 || { echo "darwin: loader 的 USB 沒出現"; exit 1; }
fi
timeout 10 fastboot getvar version 2>&1 | grep -q "version:" || sleep 5

# 2. iOS 系統映像進手機記憶體
if [ "$SYS" != none ]; then
	T0=$(date +%s)
	timeout 10 fastboot oem ramdisk 2>&1 | grep -q OKAY || { echo "darwin: loader 拒絕（記憶體視窗？）"; exit 1; }
	timeout 1800 fastboot stage "$SYS" 2>&1 | grep -q OKAY || { echo "darwin: 系統映像上傳失敗"; exit 1; }
	echo "darwin: 系統映像 $(( $(stat -f %z "$SYS") / 1048576 )) MB 上傳完成，$(( $(date +%s) - T0 )) 秒"
fi

# 3. 核心＋小 ramdisk，開跑
cd "$K"
python3 xnuloader/mkpayload.py -o build/darwin-run.bin kernel="$KERNEL" ${RD:+ramdisk="$RD"} --cmdline "$CMDLINE" >/dev/null
timeout 60 fastboot stage build/darwin-run.bin 2>&1 | grep -q OKAY || { echo "darwin: payload 上傳失敗"; exit 1; }
timeout 10 fastboot oem run >/dev/null 2>&1 || true
echo "darwin: 核心開跑 $(date +%T)，最多 $SECS 秒"
DEADLINE=$(( $(date +%s) + SECS + 100 )); result=
while [ $(date +%s) -lt $DEADLINE ]; do
	result=$(timeout 15 fastboot getvar result 2>&1 | grep '^result:' || true)
	case "$result" in ""|*running*) ;; *) break ;; esac
	# 即時紀錄：每輪抓一次核心還在跑時的紀錄，當機也留得下最後幾秒（loader 的 oem log + get_staged，依序不並行）
	if timeout 15 fastboot oem log >/dev/null 2>&1 && timeout 60 fastboot get_staged "$LOG.live.tmp" >/dev/null 2>&1; then
		mv -f "$LOG.live.tmp" "$LOG.live"
	fi
	sleep 2
done
case "$result" in ""|*running*) echo "darwin: 沒有結果（核心可能卡住），請拍螢幕"; exit 2 ;; esac
timeout 120 fastboot get_staged "$LOG" >/dev/null 2>&1 || true
echo "darwin: ${result}，紀錄 ${LOG}（$(wc -c < "$LOG" 2>/dev/null) bytes）"
