#!/bin/bash
# 可接續的平行分段下載：pget2.sh URL OUT [段數] —— 分段檔放在 OUT.parts/，斷線或重跑都從各段已下載的位置接續
set -e
URL=$1; OUT=$2; N=${3:-8}
LEN=$(curl -sIL "$URL" | grep -i '^content-length' | tail -1 | tr -dc 0-9)
[ -n "$LEN" ] || { echo "pget2: 取不到大小"; exit 1; }
D=$OUT.parts; mkdir -p "$D"; STEP=$(( (LEN + N - 1) / N ))
for i in $(seq 0 $((N-1))); do
  S=$((i*STEP)); E=$((S+STEP-1)); [ $E -ge $LEN ] && E=$((LEN-1)); NEED=$((E-S+1))
  ( touch "$D/$i"
    while :; do
      HAVE=$(stat -f %z "$D/$i"); [ "$HAVE" -ge "$NEED" ] && break
      curl -sL --fail --max-time 600 -r $((S+HAVE))-$E "$URL" >> "$D/$i" || sleep 2
    done ) &
done
wait
for i in $(seq 0 $((N-1))); do cat "$D/$i"; done > "$OUT"
[ $(stat -f %z "$OUT") -eq $LEN ] && rm -rf "$D" && echo "pget2: $OUT $LEN bytes"
