#!/bin/bash
# 平行分段下載：pget.sh URL OUT [段數]（網路單連線很慢時用）
set -e
URL=$1; OUT=$2; N=${3:-8}
LEN=$(curl -sIL "$URL" | grep -i '^content-length' | tail -1 | tr -dc 0-9)
[ -n "$LEN" ] || { echo "pget: 取不到大小"; exit 1; }
D=$(mktemp -d "${OUT}.parts.XXXX"); STEP=$(( (LEN + N - 1) / N ))
for i in $(seq 0 $((N-1))); do
  S=$((i*STEP)); E=$((S+STEP-1)); [ $E -ge $LEN ] && E=$((LEN-1))
  ( until curl -sL --fail -r $S-$E -o "$D/$i" "$URL" && [ $(stat -f %z "$D/$i") -eq $((E-S+1)) ]; do sleep 2; done ) &
done
wait
for i in $(seq 0 $((N-1))); do cat "$D/$i"; done > "$OUT"; rm -rf "$D"
[ $(stat -f %z "$OUT") -eq $LEN ] && echo "pget: $OUT $LEN bytes"
