#!/bin/bash
# 在 U-Boot 裡每 0.5 秒讀一次 PM8998：PON 即時狀態（0x810）、GPIO5（0xc410）、GPIO6（0xc510），有變化才印（唯讀）
SECS=${1:-180}; END=$(( $(date +%s) + SECS )); last=""
timeout 15 fastboot oem console >/dev/null 2>&1
fastboot oem run:"pmic dev pmic@0" >/dev/null 2>&1
while [ $(date +%s) -lt $END ]; do
	for r in 0x810 0xc410 0xc510; do timeout 3 fastboot oem run:"pmic read $r" >/dev/null 2>&1; done
	v=$(timeout 5 fastboot oem console 2>&1 | sed 's/^(bootloader) //' | grep -E "^0x(810|c410|c510):" | tr '\n' ' ')
	if [ "$v" != "$last" ]; then echo "$(date +%T.%N | cut -c1-12)  $v"; last=$v; fi
	sleep 0.4
done
echo "監看結束"
