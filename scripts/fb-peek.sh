#!/bin/bash
# 從 U-Boot（fastboot oem run）讀回螢幕緩衝區的一小塊，畫成文字圖：fb-peek.sh <文字列號 0..72> [寬度像素=160]
# 讀的時候先把 U-Boot 的輸出從螢幕拿掉，免得一邊讀一邊捲動；讀完還原。
row=${1:-71}; w=${2:-160}
base=$((0x9d400000 + row*32*4320))
q() { fastboot oem "run:$1" >/dev/null 2>&1; }
q "setenv stdout serial"
fastboot oem console >/dev/null 2>&1
q "setenv d 'md.l \$a $(printf %x $w);setexpr a \$a + 21c0'"
q "setenv a $(printf %x $base)"
out=""
for part in 1 2; do
  q "run d d d d d d d d"
  out+=$(fastboot oem console 2>&1 | sed 's/^(bootloader) //')$'\n'
done
q "setenv stdout serial,vidconsole"
printf '%s' "$out" | python3 -I -c '
import sys,re
w=int(sys.argv[1]); px=[]
for l in sys.stdin:
    m=re.match(r"^9d[0-9a-f]{6}: ((?:[0-9a-f]{8} ?)+)",l)
    if m: px+=m.group(1).split()
rows=[px[i:i+w] for i in range(0,len(px),w)]
print("讀回 %d 列 x %d 像素"%(len(rows),w))
for r in rows: print("".join("#" if int(p,16)&0xffffff else " " for p in r).rstrip())
' "$w"
