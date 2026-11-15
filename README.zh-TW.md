# HakiOS 跑在 OnePlus 6T（`fajita`）

**Darwin（XNU）核心＋iOS 16.5 使用者空間，跑在 OnePlus 6T（Snapdragon 845）上。**
開得進主畫面，GPU、觸控、Wi-Fi、**LTE 行動數據**、**喇叭出聲**、**麥克風**、藍牙（**BLE 鍵盤能打字**）、充電、震動、手電筒都能用，整套系統只跑在記憶體裡。Safari 能開網頁，Wi‑Fi 會自動連回已知網路。

**目前版本：Beta 0.5（`v0.5-beta`，2026 年 11 月）**——安裝到手機後按電源鍵直接進 iOS，資料存在手機上約 20 GB 的磁碟區；見[版本說明](releases/v0.5-beta.md)與[測試 Beta 0.5](#測試-beta-05)。

這是 [HakiOS](https://github.com/oosexgang/hakios-xnu-kernel) 的裝置移植。HakiOS 把開源的 XNU 核心搬到高通手機上，
上游參考機是 POCO X5 Pro（Snapdragon 778G）。6T 是不同世代的晶片，所以 GPU、數據機、IPA、Wi-Fi、觸控、電池、亮度、
閃光燈、震動的驅動，都要為它另外寫或移植。

[English](README.md)

> **與 Apple、OnePlus、高通無關。** 這個 repo 不含任何 Apple 軟體、iOS 映像或原廠韌體。IPSW 要自己向 Apple 下載，
> 韌體要從自己的手機取出。這樣使用是否合法，由你自己判斷（見上游 [LEGAL.md](https://github.com/oosexgang/hakios-xnu-kernel/blob/main/LEGAL.md)）。
> Apple 服務（啟用、Apple ID、App Store）不支援，也不打算支援。

## 能用的功能

2026 年 11 月在實機上確認的結果（完整清單在 [`device.conf`](device.conf)）：

| 項目 | 6T | 上游參考機（redwood） | 說明 |
|---|---|---|---|
| 鎖定畫面、主畫面、內建 App | ✅ | ✅ | SpringBoard、設定、Safari（Beta 0.3 起能載入網頁）、健康… |
| 觸控、實體按鍵 | ✅ | ✅ | Synaptics S3706B（I2C 上的 RMI4），為 6T 自寫 |
| 8 核心、CPU 調頻 | ✅ | ✅ | SDM845 OSM 頻率表，依負載調整 |
| GPU（Mesa 的 OpenGL ES 3.2） | ✅ | ✅ | **Adreno 630 從零點亮**，最高 60 fps |
| Wi-Fi | ✅ | ✅ | WCN3990＋Linux ath10k；在 iOS 設定加入網路，**5 GHz 約 95～110 Mbps**；已知網路會自動連回 |
| 電量顯示 | ✅ | ✅ | PMI8998 電量計，顯示在狀態列 |
| **在這個核心下充電** | ✅ | ❌ | 一輪內 41% → 64%，USB 1 A |
| **行動網路：LTE 註冊＋上網** | ✅ | 部分（未註冊） | 遠傳 LTE 4 格；Safari 走 LTE，下載 88 MB、上傳 56 MB，IPA 0 錯誤（`ipa8=11`） |
| **手電筒** | ✅ | 部分 | 控制中心按鈕開關 |
| **螢幕亮度** | ✅ | — | 設定與控制中心的滑桿（DSI 指令模式） |
| 溫度保護 | ✅ | 部分 | 21 個感測器，GPU、CPU 依負載降頻 |
| 震動 | ✅ | ✅ | PMI8998 線性馬達，預設開啟（比 iPhone 大力，待調） |
| 儲存 | 部分 | ✅ | `/private/var` 可跨開機保留，存在從 userdata 切出的 `darwin` 分區（開發用；測試包還不會建這個分區） |
| 定位 | 部分 | — | 數據機 GPS（QMI LOC）接到定位服務（`gnss=1`）；路徑已通，戶外定位尚未實測 |
| **聲音（喇叭）** | ✅ | ✅ | iOS 系統音、鍵盤音、YouTube：ADSP → I2S → TFA9894 功放（旁路模式）；為保護喇叭限制在 −20 dBFS；預設開啟 |
| **麥克風** | ✅ | ✅ | 語音備忘錄能錄音：底部麥克風（AMIC4）→ WCD9340 → SLIMbus → ADSP；只在錄音時通電 |
| 相機 | ❌ | ✅ | 還沒開始 |
| 藍牙 | 部分 | ❌ | WCN3990（UART）：iOS 能開藍牙、掃描、和 Mac 配對（`bt=4`）；**BLE 鍵盤能配對、打字**（BTLEServer）；重開機後配對不保留 |
| SSH | ✅ | ✅ | `sshd`，只收你自己的金鑰（`RC_JOBS=rc.jobs.ssh6t`）；預裝 `neofetch`，登入就顯示 |

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
完全不碰。數據機要用的檔案系統，是從記憶體裡的副本以唯讀方式提供。開 `ipa8=11` 時，會改數據機的兩個數據設定（數據開關、預設數據 SIM），
只改在數據機的記憶體裡，不寫回分區。

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
| LTE 註冊約 2 分鐘後 Wi-Fi 就掛 | 數據機在 LTE 下行斷言失敗（`ipa_dl_opt_lte.c: IPA Assert new_free_space > 0`）：IPA 沒設好，封包沒地方放；Wi-Fi 韌體跑在數據機上，所以一起死 | 把 IPA 做起來；在那之前數據機預設不上線 |
| TrustZone 一啟動 IPA 韌體就進 QCOM | 我們起頭用的 IPA 初始化寫的是 **IPA v4.11** 的暫存器位址，SDM845 是 **v3.5.1**，寫錯地方讓匯流排卡死。更早之前，TrustZone 不收保留 mbn 填充空白的 `.mdt` | 全面改用 v3.5.1 的配置；產生緊密的 `.mdt`；驗證前先照 Linux 投匯流排票 |
| LTE 註冊了，開數據卻一直被拒（「沒有服務」） | Android 時期留在數據機裡的設定：數據開關**關**、預設數據 SIM 是**第 2 槽** | 經使用者同意送兩個 DSD 寫入（只在數據機記憶體）；SIM 改成跟 postmarketOS 一樣、不切卡槽 |
| Safari 一直轉圈，但網路是通的 | 這台手機上 `mobileactivationd` 一啟動就崩潰，排隊的請求永遠不回；`apsd` 啟動時問它、`amsaccountsd` 問 `apsd`，Safari 主執行緒就卡在等 AppleMediaServices（用 stackshot 抓 Safari 執行緒才看出來） | 不啟動這個服務（`mkjobs.py` DENY），問它的程式立刻拿到錯誤 |
| 已知的 Wi-Fi 網路不會自動連回 | wifid 開機時向驅動要自動加入的最低訊號門檻（`APPLE80211_IOC_RSSI_BOUNDS`）；驅動不回答，門檻停在 **0 dBm**，每個網路都「低於最低 RSSI 門檻」——反組譯 `wifid` 才找到 | 驅動回答（−90／−20 dBm，門檻 −80）；電台還沒好時的開電源請求先接受、不拒絕 |

## 相關 repo

| Repo | 內容 |
|---|---|
| **本 repo**（`hakios-fajita`） | 裝置層：設定檔、SoC 層（`soc/`，sdm845）、U-Boot 機型檔與修補、腳本、狀態 |
| [`kiwiiiii-eth/hakios-xnu-kernel`](https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/fajita) 的 **`fajita`** 分支 | 核心與所有新驅動：`drivers/gpu/hakios.a630.c`、`hakios.dsibl.c`、`drivers/modem/hakios.mpss845.c`、`drivers/wifi/hakios.wifi10.c`＋`wifi/lx/src10/`、`drivers/modem/hakios.ipa.c`（IPA 3.5.1）、`drivers/input/hakios.rmi4.c`、`drivers/power/hakios.fg8998.c`、`drivers/camera/hakios.torch8998.c`、`drivers/haptic/hakios.haptic8998.c`、`drivers/audio/hakios.adsp845.c`、`drivers/bluetooth/hakios.bt3990.c` |
| [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel) | 上游 HakiOS：XNU 移植、loader、使用者空間、工具、文件 |
| [`oosexgang/hakios-uefi`](https://github.com/oosexgang/hakios-uefi/tree/mac) 的 `mac` 分支 | 本移植 U-Boot 使用的 HakiOS U-Boot 修補（`u-boot/`） |

## 建置與執行

步驟與指令見 [English README](README.md#building-and-running)。重點：

- 這是開發者移植，不是可安裝的 ROM。需要**已解鎖 bootloader** 的 6T，以及 Apple Silicon 的 Mac（核心用 Xcode 編譯）。
- 編核心用 `PYTHONSAFEPATH=1 make kernel`：Homebrew 的 Python 3.15 下，XNU 自帶的 `tools/lldbmacros/core/collections.py` 會蓋掉標準函式庫，第一次編譯會失敗。
- 韌體不放在 repo 裡，要從自己的手機和 linux-firmware 取得（清單見英文版「Firmware」）。
- `scripts/run-darwin-live.sh` 會自動把手機帶回 ABL fastboot、開 loader、用 USB 送 2.4 GB 系統映像（約 1 分鐘），開機並即時存紀錄到 `out/logs/`。

## 測試 Beta 0.5

最簡單的方式是用 [Beta 0.5 Release](https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.5-beta) 上的**測試包**：
核心、載入器和我們的程式都已預先編好，不用裝 Xcode。你要準備：
- 已解鎖 bootloader 的 OnePlus 6T（`run.sh` 不刷任何分區，Android 會留著；`install.sh` 會清除 Android 資料，見測試包 README）。
- 裝好 [Homebrew](https://brew.sh) 的 Mac（Apple Silicon 已測；Intel 應可用，未實測）。
- 自己下載的 iPhone X iOS 16.5 IPSW（20F66）。

```sh
brew install python sevenzip zstd coreutils android-platform-tools
tar xzf hakios-6t-v0.5-beta.tar.gz && cd hakios-6t-v0.5-beta
./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw   # 只跑一次：用 adb 從手機抽韌體、解 IPSW、組映像
./run.sh                                                               # 從 Mac 開機跑一輪 60 分鐘，不刷任何分區
./install.sh                                                           # 或安裝到手機：之後按電源鍵直接進 iOS（會清除 Android 資料）
```

- 每一步在做什麼、進主畫面後可以測什麼，見測試包的 [README](beta/README.md)。
- 測試包裡的載入器不含任何裝置身分，`setup.sh` 會從你自己的 IPSW 把身分資料填進去。
- 想全部從原始碼建置，請照英文版「Building and running」。

每一輪的紀錄會即時寫到 `out/logs/`，有問題請附在 issue 上。

## 聯絡與支持

- 問題回報：https://github.com/kiwiiiii-eth/hakios-fajita/issues
- X：[@0x718_718](https://x.com/0x718_718)
- 捐款（BTC）：`bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`

## 致謝

- **[HakiOS](https://github.com/oosexgang/hakios-xnu-kernel)**（oosexgang 與貢獻者）：XNU 移植、loader、使用者空間與工具，以及 6T 驅動參考的 redwood 驅動。
- **[ios-fajita](https://github.com/edi194/ios-fajita)**（edi194，基於 [ios-sweet](https://github.com/dipa-studio/ios-sweet)）：6T 上第一個跑起 iOS 的專案（軟體繪圖，2026 年 10 月）；開機映像參數和觸控初始化序列來自它。本移植一開始是 [它的 fork](https://github.com/kiwiiiii-eth/ios-fajita)，讀 UFS 卡關後改走 HakiOS。
- **[postmarketOS](https://postmarketos.org) 與主線 Linux** 的 SDM845 支援：證明同一份韌體能開數據機的對照實驗，以及每支重寫驅動的參考。ath10k（ISC）原封不動編在 LinuxKPI 上。
- [LineageOS](https://github.com/LineageOS/android_kernel_oneplus_sdm845) OnePlus SDM845 核心、[Mesa](https://mesa3d.org) freedreno、[U-Boot](https://u-boot.org)、[bkerler/edl](https://github.com/bkerler/edl)。

## 授權

本 repo 自己的檔案採 MIT（[LICENSE](LICENSE)）。`u-boot/` 與 `prebuilt/u-boot.bin` 是 GPL-2.0+（U-Boot），裝置樹原始碼 GPL-2.0，
`prebuilt/mkbootimg.py` 是 Apache-2.0（AOSP）。核心驅動在 `hakios-xnu-kernel`，依其授權（XNU 衍生部分 APSL 2.0，其餘 MIT）。
