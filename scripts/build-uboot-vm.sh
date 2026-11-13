#!/bin/bash
# 在 Lima VM 內執行：照 hakios-uefi/u-boot/apply.sh + build.sh 的步驟，套 HakiOS 修補與 6T 機型檔後編譯
set -e
cd ~/hakios/u-boot
if [ ! -f cmd/hakios.c ]; then
  git apply --whitespace=nowarn ../stage/hakios-uefi-u-boot/hakios.patch
  cp -r ../stage/hakios-uefi-u-boot/files/. .
fi
cp -r ../stage/fajita/files/. .
out=build-fajita
make -s O=$out CROSS_COMPILE=aarch64-linux-gnu- hakios_fajita_defconfig
make -s O=$out CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" 2>&1 | tail -40
ls -la $out/u-boot.bin $out/u-boot-nodtb.bin $out/dts/upstream/src/arm64/qcom/*.dtb
