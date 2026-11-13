#!/bin/bash
# 在 Lima VM 內執行：分批、平行抓 U-Boot v2026.07（網路每條連線只有 ~50KB/s，單一大請求容易斷）
set -u
cd ~/hakios || exit 1
rm -rf u-boot
git init -q u-boot && cd u-boot || exit 1
git remote add origin https://github.com/u-boot/u-boot.git
git config remote.origin.promisor true
git config remote.origin.partialclonefilter blob:none
git config gc.auto 0
git config advice.detachedHead false

for i in 1 2 3 4 5; do
  git fetch -q --depth 1 --filter=blob:none --no-tags origin refs/tags/v2026.07:refs/tags/v2026.07 && break
  echo "tree fetch retry $i"; sleep 3
done
git rev-parse -q --verify v2026.07^{commit} >/dev/null || { echo "TREE FETCH FAILED"; exit 1; }
echo "trees ok: $(git rev-parse --short v2026.07^{commit})  $(du -sh .git | cut -f1)"

mkdir -p ../chunks && rm -f ../chunks/*
git ls-tree -r v2026.07^{commit} | awk '$2=="blob"{print $3}' | sort -u > ../chunks/all
echo "blobs: $(wc -l < ../chunks/all)"
split -n r/24 -d ../chunks/all ../chunks/c

fetch_chunk() {
  local f=$1
  for i in 1 2 3 4 5 6; do
    if git -c fetch.negotiationAlgorithm=noop fetch -q origin --no-tags --no-write-fetch-head \
         --recurse-submodules=no --filter=blob:none --stdin < "$f" 2>>"$f.err"; then
      echo "ok $(basename "$f")"; return 0
    fi
    sleep 2
  done
  echo "FAIL $(basename "$f")"; return 1
}
export -f fetch_chunk
ls ../chunks/c[0-9]* | grep -v '\.err$' | xargs -P 8 -I{} bash -c 'fetch_chunk {}'

missing=$(git cat-file --batch-check='%(objecttype)' --batch-all-objects >/dev/null 2>&1; \
          git -c fetch.negotiationAlgorithm=noop cat-file --batch-check < ../chunks/all 2>/dev/null | grep -c missing)
echo "missing blobs: $missing  .git=$(du -sh .git | cut -f1)"
[ "$missing" = 0 ] || { echo "INCOMPLETE"; exit 2; }
git checkout -q v2026.07 && echo "checkout ok: $(git log --oneline -1)  files=$(git ls-files | wc -l)  size=$(du -sh --exclude=.git . | cut -f1)"
