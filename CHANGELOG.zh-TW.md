# 更新紀錄

HakiOS for OnePlus 6T 的每一個版本。完整說明（含各版已知問題）在 [`releases/`](releases/) 與
[Releases 頁面](https://github.com/kiwiiiii-eth/hakios-fajita/releases)。[English](CHANGELOG.md)

## [0.7.1-beta] — 2026-11-24

### 修正
- **開機後第一次以後的錄音都沒聲音**（[#2](https://github.com/kiwiiiii-eth/hakios-fajita/issues/2)）：麥克風的 SLIMbus 裝置在兩次錄音之間會保留邏輯位址，驅動卻在等只有新位址才會有的交握，等不到就放棄，連三次後麥克風整個關掉，要重開機才回來。現在保留位址的裝置直接沿用。由 @tre4surehunter9 回報。
- Wi‑Fi 還在掃描時關機或重開會當機：卸下驅動前先讓基地台相關的呼叫結束，並停掉驅動的計時器。
- 系統映像保留**中文**（繁體、香港、簡體）：「設定 → 一般 → 語言與地區」現在能把 iOS 切成中文（以前語言檔沒放進去，切了沒反應）。

## [0.7-beta] — 2026-11-23

### 新增
- **AirPods**：打開 AirPods 盒蓋時 iOS 跳出的卡片，現在有 AirPods 和「連線」，AirPods Pro 2 能配對、能聽。`mobileassetd` 會跑了（卡片的圖由它下載），核心對「資料夾的資料保護等級」回答 D（不保護）而不是「不支援」，下載的圖才解得開。
- **由顯示控制器縮放、翻頁**（`fb_hw`，預設開；`fb_hw=0` 回到 CPU 縮放）：每一幀原樣複製進兩塊緩衝區之一，由控制器自己的縮放器（VIG0 的 QSEED3）縮成面板大小。開動態島、35 個手勢的自動滑動量測：晚於 16.7 ms 的幀 13% → 3～4%，晚於 33 ms 的 2% → 1%；複製 2 ms，原本 CPU 縮放要 8～11 ms；不再撕裂。

### 改進
- 藍牙晶片的連線改成 3.2 Mbit/s（原本 115200 bit/s，約 90 kbit/s 的資料量，AirPods 的串流要 256）：耳機不再破音、斷斷續續。`bt_baud=115200` 可改回。

### 修正
- **藍牙配對**重開機後會保留。系統共用容器的資料夾（藍牙、地圖、電池紀錄等）從 0.5 起使用者 `mobile` 都寫不進去，現在每次開機都會改回來。
- **相機先占用音訊的 SMMU context 時，喇叭和麥克風全啞**（[#1](https://github.com/kiwiiiii-eth/hakios-fajita/issues/1)）。context 的暫存器是透過先前選到的那個 context 的對應讀的，遇到被占用的 context 也會直接放棄。由 @tre4surehunter9 回報、診斷並修好，他的修補原樣併入。
- 約一半的開機喇叭沒聲音（兩個步驟之間被別的驅動拿走 SMMU context）。
- 「設定 → 一般 → 關於」改的手機名稱會保留（`lockdownd` 會跑了）。
- 「檔案」和 TrollStore 的選檔畫面能打開（它們的擴充功能已向 LaunchServices 註冊）。
- 長時間使用、開很多檔案後的當機（`kern.maxvnodes` 提高到 65536）。

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
