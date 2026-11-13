# HakiOS 跑在 OnePlus 6T（`fajita`）

**Darwin（XNU）核心＋iOS 16.5 使用者空間，跑在 OnePlus 6T（Snapdragon 845）上。**
開得進主畫面，GPU、觸控、Wi-Fi、充電、手電筒都能用，整套系統只跑在記憶體裡。

這是 [HakiOS](https://github.com/oosexgang/hakios-xnu-kernel) 的裝置移植。HakiOS 把開源的 XNU 核心搬到高通手機上，
上游參考機是 POCO X5 Pro（Snapdragon 778G）。6T 是不同世代的晶片，所以 GPU、數據機、Wi-Fi、觸控、電池、亮度、
閃光燈、震動的驅動，都要為它另外寫或移植。

[English](README.md)

> **與 Apple、OnePlus、高通無關。** 這個 repo 不含任何 Apple 軟體、iOS 映像或原廠韌體。IPSW 要自己向 Apple 下載，
> 韌體要從自己的手機取出。這樣使用是否合法，由你自己判斷（見上游 [LEGAL.md](https://github.com/oosexgang/hakios-xnu-kernel/blob/main/LEGAL.md)）。
> Apple 服務（啟用、Apple ID、App Store）不支援，也不打算支援。

## 能用的功能

2026 年 11 月在實機上確認的結果（完整清單在 [`device.conf`](device.conf)）：

| 項目 | 6T | 上游參考機（redwood） | 說明 |
|---|---|---|---|
| 鎖定畫面、主畫面、內建 App | ✅ | ✅ | SpringBoard、設定、Safari、健康… |
| 觸控、實體按鍵 | ✅ | ✅ | Synaptics S3706B（I2C 上的 RMI4），為 6T 自寫 |
| 8 核心、CPU 調頻 | ✅ | ✅ | SDM845 OSM 頻率表，依負載調整 |
| GPU（Mesa 的 OpenGL ES 3.2） | ✅ | ✅ | **Adreno 630 從零點亮**，最高 60 fps |
| Wi-Fi | ✅ | ✅ | WCN3990＋Linux ath10k；在 iOS 設定加入網路，**5 GHz 約 95～110 Mbps** |
| 電量顯示 | ✅ | ✅ | PMI8998 電量計，顯示在狀態列 |
| **在這個核心下充電** | ✅ | ❌ | 一輪內 41% → 64%，USB 1 A |
| **手電筒** | ✅ | 部分 | 控制中心按鈕開關 |
| **螢幕亮度** | ✅ | — | 設定與控制中心的滑桿（DSI 指令模式） |
| 溫度保護 | ✅ | 部分 | 21 個感測器，GPU、CPU 依負載降頻 |
| 震動 | 🚧 | ✅ | PMI8998 線性馬達驅動已寫好，測試中 |
| 行動網路 | 部分 | 部分 | 數據機能開機並持續運作；還沒註冊 SIM |
| 儲存 | 唯讀 | ✅ | `/private/var` 重開機後不保留 |
| 聲音、麥克風、相機 | ❌ | ✅ | 還沒開始 |
| 藍牙 | ❌ | ❌ | |

## 開機流程

不刷任何分區，重開機就回到手機原本的 Android。

```
ABL（原廠 bootloader）── fastboot boot ──▶ U-Boot ── hakios load ──▶ HakiOS loader（UEFI 程式）
      ▲                                                                 │ 把系統映像放進記憶體
      └─ 在 PMIC 寫入重開原因，之後任何重開都回 fastboot                     ▼
                                                              XNU 8796 ─▶ launchd ─▶ SpringBoard
```

**會寫入手機的東西**：一個 PMIC 暫存器（重開原因 `0x88f`，讓重開後停在 fastboot）。系統執行時，會寫充電器的輸入與充電電流上限、
閃光燈和震動模組；每一項都限定在暫存器白名單內，寫完都會讀回比對。不寫任何分區：`persist`、`modemst*`、`fsg`、`xbl`、`abl`、`tz`
完全不碰。數據機要用的檔案系統，是從記憶體裡的副本以唯讀方式提供。

## 最難的幾關

花最多時間的問題，記下來給下一個 SDM845 移植參考：

| 問題 | 原因 | 修法 |
|---|---|---|
| 核心在畫面出來後就停住 | XNU 把 EL1 虛擬計時器中斷寫死成 27，SDM845 是 **19** | 開機參數 `gic_vtimer=`（`soc/configs/sdm845.config` 的 `CONFIG_GIC_VTIMER=19`） |
| 觸控只有拔掉 USB 線才能用 | USB 雜訊；控制器有「充電器已連接」位元（F01 ctrl0 bit 5） | 驅動每 0.5 秒讀 PMIC 的 USBIN，自動設定該位元 |
| GMU 幫 GPU 上電，卻不設定 PLL | A630 的 GMU 韌體要的晶片 ID 是 **0x06030200**（630.2），不是裝置樹的 0x06030000；RSCC／PDC 要在 GMU 啟動**之前**寫好 | 兩者修正後，再補上 DCVS 頻率投票（沒送時每次等 GPU 要 70～185 ms） |
| 數據機的 MBA 收到驗證標頭 0.4 秒後，手機進高通 CrashDump | 用 EDL 從 CrashDump 讀出 TrustZone 診斷紀錄：`QDSP6SS_SLEEP` 發生 **NoC 錯誤**。是我們自己的除錯讀取，在 MBA 用 XPU 鎖住 QDSP6SS 之後還去讀 | 交出標頭後不再存取 QDSP6SS（Linux 本來就不讀） |
| 數據機起來了，Wi-Fi 韌體服務卻沒出現 | 只要我們預先配置 IPA 的 SMEM 項目、或提到 IPA，數據機就斷言失敗 | 照 Linux 配 GLINK SMEM 478／479，完全不提 IPA |
| Wi-Fi 偶爾 WMI 逾時 | NAPI 輪詢和中斷搶時序：輪詢途中進來的排程被丟掉，該通道的中斷一直被遮住 | NAPI 補上 Linux 的「missed」語意 |
| 加入網路、WPA2 也過了，IP 卻停在 169.254 | `lx_transmit` 送封包入口還是佔位程式，一律回 `ENETDOWN` | 接上真正的送出路徑；DHCP 成功、Safari 能上網 |
| 插著電，電池還是一直掉 | ABL 留下的輸入上限是 500 mA、充電電流是 **0** | 兩者都設 1 A（寫完讀回、45°C 以上自動停充） |

## 相關 repo

| Repo | 內容 |
|---|---|
| **本 repo**（`hakios-fajita`） | 裝置層：設定檔、SoC 層（`soc/`，sdm845）、U-Boot 機型檔與修補、腳本、狀態 |
| [`kiwiiiii-eth/hakios-xnu-kernel`](https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/fajita) 的 **`fajita`** 分支 | 核心與所有新驅動：`drivers/gpu/hakios.a630.c`、`hakios.dsibl.c`、`drivers/modem/hakios.mpss845.c`、`drivers/wifi/hakios.wifi10.c`＋`wifi/lx/src10/`、`drivers/input/hakios.rmi4.c`、`drivers/power/hakios.fg8998.c`、`drivers/camera/hakios.torch8998.c`、`drivers/haptic/hakios.haptic8998.c` |
| [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel) | 上游 HakiOS：XNU 移植、loader、使用者空間、工具、文件 |
| [`oosexgang/hakios-uefi`](https://github.com/oosexgang/hakios-uefi/tree/mac) 的 `mac` 分支 | 本移植 U-Boot 使用的 HakiOS U-Boot 修補（`u-boot/`） |

## 建置與執行

步驟與指令見 [English README](README.md#building-and-running)。重點：

- 這是開發者移植，不是可安裝的 ROM。需要**已解鎖 bootloader** 的 6T，以及 Apple Silicon 的 Mac（核心用 Xcode 編譯）。
- 韌體不放在 repo 裡，要從自己的手機和 linux-firmware 取得（清單見英文版「Firmware」）。
- `scripts/run-darwin-live.sh` 會自動把手機帶回 ABL fastboot、開 loader、用 USB 送 2.4 GB 系統映像（約 1 分鐘），開機並即時存紀錄到 `out/logs/`。

## 致謝

- **[HakiOS](https://github.com/oosexgang/hakios-xnu-kernel)**（oosexgang 與貢獻者）：XNU 移植、loader、使用者空間與工具，以及 6T 驅動參考的 redwood 驅動。
- **[ios-fajita](https://github.com/edi194/ios-fajita)**（edi194，基於 [ios-sweet](https://github.com/dipa-studio/ios-sweet)）：6T 上第一個跑起 iOS 的專案（軟體繪圖，2026 年 10 月）；開機映像參數和觸控初始化序列來自它。本移植一開始是 [它的 fork](https://github.com/kiwiiiii-eth/ios-fajita)，讀 UFS 卡關後改走 HakiOS。
- **[postmarketOS](https://postmarketos.org) 與主線 Linux** 的 SDM845 支援：證明同一份韌體能開數據機的對照實驗，以及每支重寫驅動的參考。ath10k（ISC）原封不動編在 LinuxKPI 上。
- [LineageOS](https://github.com/LineageOS/android_kernel_oneplus_sdm845) OnePlus SDM845 核心、[Mesa](https://mesa3d.org) freedreno、[U-Boot](https://u-boot.org)、[bkerler/edl](https://github.com/bkerler/edl)。

## 授權

本 repo 自己的檔案採 MIT（[LICENSE](LICENSE)）。`u-boot/` 與 `prebuilt/u-boot.bin` 是 GPL-2.0+（U-Boot），裝置樹原始碼 GPL-2.0，
`prebuilt/mkbootimg.py` 是 Apache-2.0（AOSP）。核心驅動在 `hakios-xnu-kernel`，依其授權（XNU 衍生部分 APSL 2.0，其餘 MIT）。
