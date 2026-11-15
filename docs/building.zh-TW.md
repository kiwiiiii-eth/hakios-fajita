# 從原始碼建置

[← README](../README.zh-TW.md) · [開機流程](how-it-boots.zh-TW.md) · [硬體支援](hardware.zh-TW.md) · [最難的幾關](hard-parts.zh-TW.md) · [從原始碼建置](building.zh-TW.md) · [更新紀錄](../CHANGELOG.zh-TW.md) · [English](building.md)

## 相關 repo

| Repo | 內容 |
|---|---|
| **本 repo**（`hakios-fajita`） | 裝置層：設定檔、SoC 層（`soc/`，sdm845）、U-Boot 機型檔與修補、腳本、狀態 |
| [`kiwiiiii-eth/hakios-xnu-kernel`](https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/fajita) 的 **`fajita`** 分支 | 核心與所有新驅動：`drivers/gpu/hakios.a630.c`、`hakios.dsibl.c`、`drivers/modem/hakios.mpss845.c`、`drivers/wifi/hakios.wifi10.c`＋`wifi/lx/src10/`、`drivers/modem/hakios.ipa.c`（IPA 3.5.1）、`drivers/input/hakios.rmi4.c`、`drivers/power/hakios.fg8998.c`、`drivers/camera/hakios.torch8998.c`、`drivers/haptic/hakios.haptic8998.c`、`drivers/audio/hakios.adsp845.c`、`drivers/bluetooth/hakios.bt3990.c`；loader 的分區表規則與開機畫面（`xnuloader/gpt.c`、`bootscreen.c`） |
| [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel) | 上游 HakiOS：XNU 移植、loader、使用者空間、工具、文件 |
| [`oosexgang/hakios-uefi`](https://github.com/oosexgang/hakios-uefi/tree/mac) 的 `mac` 分支 | 本移植 U-Boot 使用的 HakiOS U-Boot 修補（`u-boot/`） |

## 建置與執行

完整步驟與指令見[英文版](building.md)。重點：

- 這仍是開發者移植。需要**已解鎖 bootloader** 的 6T，以及 Apple Silicon 的 Mac（核心用 Xcode 編譯）。
- 編核心用 `PYTHONSAFEPATH=1 make kernel`：Homebrew 的 Python 3.15 下，XNU 自帶的 `tools/lldbmacros/core/collections.py` 會蓋掉標準函式庫，第一次編譯會失敗。
- 韌體不放在 repo 裡，要從自己的手機和 linux-firmware 取得（清單見[英文版的 Firmware](building.md#firmware)）。
- `scripts/run-darwin-live.sh` 會自動把手機帶回 ABL fastboot、開 loader、用 USB 送 2.4 GB 系統映像（約 1 分鐘），開機並即時存紀錄到 `out/logs/`。
- 要安裝到手機：`WORK=$PWD hakios-fajita/beta/install.sh`（**會清除 Android 資料**，見 `beta/README.md`）。
- `prebuilt/u-boot-install.bin` 是同一份 U-Boot 用 `hakios_fajita_install_defconfig` 編的安裝版（螢幕上不印 U-Boot 文字、loader 前清除重開原因、loader 回來時進 ABL fastboot）。

## 測試包的內容從原始碼建置

測試包由 `scripts/mk-beta-kit.sh` 從這些原始碼打包。要自己建出同樣的內容，照上面的步驟，改用
`BT=1 GL=1 REST=1 MODEM=1 SYSTEM=1 RC=rc.launchd.aks RC_JOBS=rc.jobs.ssh6t userland/build.sh`，SSH 金鑰放在 `hakios-xnu-kernel/ssh/`，
再跑 `make firmware`（本 repo 的 `pull-firmware.sh`）。測試包裡的 loader 不含任何裝置身分，`setup.sh` 會從你自己的 IPSW 把身分資料填進去（`xnuloader/mkidentity.py --fill`）。
