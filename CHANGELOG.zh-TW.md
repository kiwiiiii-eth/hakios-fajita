# 更新紀錄

HakiOS for OnePlus 6T 的每一個版本。完整說明（含各版已知問題）在 [`releases/`](releases/) 與
[Releases 頁面](https://github.com/kiwiiiii-eth/hakios-fajita/releases)。[English](CHANGELOG.md)

## [0.6.1-beta] — 2026-11-16

### 修正
- **動態島**（`ISLAND=1`）原本被當成有 Home 鍵的機型：沒有手勢、舊式狀態列、島壓在圖示上。現在 loader 會給 `/buttons home-button-type` 2（MobileGestalt 的 HomeButtonType），`island=1` 也會回報 14 Pro 的螢幕（1179 x 2556，縮放到面板）。每種安裝都有 `/buttons`，瀏海版面也不再依賴舊快取。

### 新增
- `tel=1`（實驗中）：收到的簡訊寫進記錄，只讀不改；打電話需要 VoLTE，這裡還沒有。

## [0.6-beta] — 2026-11-16

### 新增
- **相機**：相機 App 的主鏡頭（IMX519）約每秒 30 幀，有自動對焦與光學防手震；前鏡頭（IMX371）也能用；拍照取四張中最清楚的一張。色彩用手機原廠調校，`setup.sh` 會連同其他相機檔一起從手機抽出（adb，或透過 loader 唯讀讀取）。`cam_full=1` 用主鏡頭完整 1600 萬畫素；`cam_ois=0` 關閉防手震。
- **TrollStore 2.1.1**：第一次開機時自動安裝（`TROLLSTORE=0 ./setup.sh` 可不裝）。
- **可選動態島**：`ISLAND=1 ./install.sh`，或 `EXTRA="island=1" ./run.sh`。

### 改進
- 照片預設存 JPEG（格式 → 最相容），之前自己選過的維持原選擇。
- 相機運作時 GPU 維持高速；手機過熱時相機少出幀，不再把 CPU 鎖在最高速。

### 修正
- 前鏡頭畫面偏紫；前後鏡頭切換時會「喀」一聲。

## [0.5-beta] — 2026-11-15

### 新增
- **20 GB 資料磁碟區**：`/private/var` 改用 `darwin` 12 GiB 之後的 HFS+（有日誌），iOS 寫的東西直接存在 flash。
- **開機畫面**：HakiOS 字樣、讀取與檢查系統映像的進度條、底部的開機資訊。`DEBUG=1 ./install.sh` 會改顯示 loader 的記錄。
- 安裝或更新後的第一次開機，會把 Beta 0.4 存的資料搬進磁碟區，只搬一次，而且只在完整讀回時才算數。
- 定位（實驗中，`gnss=1`）：室內就能追到衛星，定位服務自動打開，Safari 網頁定位拿得到位置。

### 改進
- iOS 重新開機不到 1 分鐘（0.4 要先花約 1 分鐘存 `/private/var`）；強制重開也安全。
- 安裝版的 U-Boot 不再把文字蓋在畫面上。
- `install.sh` 會建立資料磁碟區（只做一次，用 macOS 的 `newfs_hfs`）；`GIB=` 可設 20～64。從 0.4 更新就是再跑一次 `./install.sh`。

### 修正
- 「設定 → 一般 → 關於本機」原本只顯示約 1 GB，現在顯示 21 GB。
- 「設定 → 一般 → iPhone 儲存空間」原本是空的，現在會統計資料磁碟區。

## [0.4-beta] — 2026-11-15

### 新增
- **安裝到手機**：`./install.sh` 把 HakiOS 裝進 Android 沒在用的 slot，**按電源鍵直接進 iOS**，不用 Mac。`./switch.sh android|hakios` 切換；`./uninstall.sh` 全部還原。
- 從 userdata 尾端切出 `darwin` 分區（預設 32 GiB；**會清除 Android 資料**）；loader 寫分區表前會對照兩份副本檢查，寫完讀回。
- 安裝前把所有會改動的東西備份到 `~/HakiOS-6T-backup/<序號>/`。
- iOS 關機或重開時把 `/private/var` 存進 `darwin`，下次開機讀回。
- 關機期間靠手機的 RTC 計時，開機時間正確；時區跟著行動網路（NITZ）。

### 改進
- iOS 的「關機」「重新開機」會真的斷電或重開。
- 從 Mac 開機一輪預設 1 小時，結束後回到 fastboot。

### 修正
- 電信商名稱顯示成四個方塊（缺一個字重）。

## [0.3-beta] — 2026-11-15

### 新增
- 定位（實驗中，`gnss=1`）：數據機的 GPS 接到定位服務。
- SSH 上的診斷工具：`stacks`、`logdump`、`socks`。
- 給開發者：`/private/var` 存在 `darwin` 分區、重開後保留（`ufs_write=1 var_store=1`）。

### 改進
- 畫面更順、開機更快：滑動每秒 55～60 幀（原本約 50），小工具改在背景執行。

### 修正
- **Safari 能載入網頁**：原本網路通了卻一直轉圈（不再啟動 `mobileactivationd`）。
- **Wi‑Fi 會自動連回已知網路**（自動加入的訊號門檻原本卡在 0 dBm）。

## [0.2-beta] — 2026-11-14

### 新增
- **麥克風**：語音備忘錄能錄音、播放。
- **BLE 鍵盤**在「設定 → 藍牙」配對後能打字。
- 在實機上確認鈴聲可用（設定 → 聲音與觸覺 → 鈴聲）。

### 改進
- 觸控改成穩定每秒讀 120 次（原本約 80 次且不均勻），手指一碰 CPU、GPU 就全速。

## [0.1-beta] — 2026-11-14

第一個給測試者的版本：從 Mac 經 USB 開機，整套系統在記憶體裡。

### 新增
- **喇叭出聲**（限制在 −20 dBFS）。
- **藍牙**（`bt=4`）：能開啟、掃描、和 Mac 配對。
- **LTE 上網**（`ipa8=11`），狀態列顯示電信商名稱與訊號格。
- 用自己金鑰的 SSH，以及 `neofetch`。
- 系統映像內附鈴聲。

### 修正
- 核心 I/O 映射空間用完造成的 panic（從 8 MB 加大到 128 MB）。
- panic 訊息在關閉硬體前先存下；一輪結束時依序停止數據機。

[0.5-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.5-beta
[0.4-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.4-beta
[0.3-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.3-beta
[0.2-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.2-beta
[0.1-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.1-beta
