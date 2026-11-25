# 硬體支援

[← README](../README.zh-TW.md) · [開機流程](how-it-boots.zh-TW.md) · [硬體支援](hardware.zh-TW.md) · [最難的幾關](hard-parts.zh-TW.md) · [從原始碼建置](building.zh-TW.md) · [更新紀錄](../CHANGELOG.zh-TW.md) · [English](hardware.md)

2026 年 11 月（Beta 0.8.1）在實機上確認的結果，並列上游 HakiOS 參考機（POCO X5 Pro，代號 redwood，Snapdragon 778G）。
含各項核心選項的完整清單在 [`device.conf`](../device.conf)。✅ 可用・部分・❌ 還不能用。

| 項目 | 6T | 上游參考機（redwood） | 說明 |
|---|---|---|---|
| 鎖定畫面、主畫面、內建 App | ✅ | ✅ | SpringBoard、設定、Safari（Beta 0.3 起能載入網頁）、健康… |
| **自己開機（安裝）** | ✅ | ✅ | `install.sh`（Beta 0.4）：HakiOS 裝進 Android 沒在用的 slot，開機時從 `darwin` 讀系統映像，畫面是有進度條的開機畫面（Beta 0.5）；iOS 的關機、重新開機可用；Android 用 `set_active` 就能切回 |
| 時鐘與時區 | ✅ | — | PMIC 的 RTC 加上保存的差值；時區跟著行動網路（NITZ） |
| 觸控、實體按鍵 | ✅ | ✅ | Synaptics S3706B（I2C 上的 RMI4），為 6T 自寫 |
| 8 核心、CPU 調頻 | ✅ | ✅ | SDM845 OSM 頻率表，依負載調整 |
| GPU（Mesa 的 OpenGL ES 3.2） | ✅ | ✅ | **Adreno 630 從零點亮**，最高 60 fps |
| Wi-Fi | ✅ | ✅ | WCN3990＋Linux ath10k；在 iOS 設定加入網路，**5 GHz 約 95～110 Mbps**；已知網路會自動連回 |
| 電量顯示 | ✅ | ✅ | PMI8998 電量計，顯示在狀態列 |
| **在這個核心下充電** | ✅ | ❌ | 一輪內 41% → 64%，USB 1 A |
| **行動網路：LTE 註冊＋上網** | ✅ | 部分（未註冊） | 由 iOS 自己的 CommCenter 控制數據機（Beta 0.8）：「設定 → 行動服務」、電信商設定檔、IPv4 與 IPv6（原生 `pdp_ip` 介面）；遠傳 LTE 實測 |
| **個人熱點** | ✅ | — | WCN3990 當 WPA2 基地台，DHCP 加從行動數據出去的 NAT（Beta 0.8.1）：從「設定」或控制中心打開，2.4 或 5 GHz（最大化相容性），狀態列熱點圖示；802.11g/a，最快 54 Mbps |
| **手電筒** | ✅ | 部分 | 控制中心按鈕開關 |
| **螢幕亮度** | ✅ | — | 設定與控制中心的滑桿（DSI 指令模式） |
| 溫度保護 | ✅ | 部分 | 21 個感測器，GPU、CPU 依負載降頻 |
| 震動 | ✅ | ✅ | PMI8998 線性馬達，預設開啟（比 iPhone 大力，待調） |
| **儲存** | ✅ | ✅ | `/private/var` 是從 userdata 切出的 `darwin` 分區裡約 20 GB 的 HFS+ 磁碟區（有日誌，Beta 0.5）：直接存在 flash，設定看得到完整容量，「iPhone 儲存空間」也正常統計 |
| 定位 | 部分 | — | 數據機 GPS（QMI LOC）接到定位服務（`gnss=1`）：能追到衛星（室內就有 23 顆），定位服務會自動打開，Safari 網頁定位拿得到位置；Apple 地圖需要已啟用的裝置 |
| **聲音（喇叭）** | ✅ | ✅ | iOS 系統音、鍵盤音、YouTube：ADSP → I2S → TFA9894 功放（旁路模式）；為保護喇叭限制在 −20 dBFS；預設開啟 |
| **麥克風** | ✅ | ✅ | 語音備忘錄能錄音：底部麥克風（AMIC4）→ WCD9340 → SLIMbus → ADSP；只在錄音時通電 |
| 相機 | 部分 | ✅ | 主鏡頭（自動對焦、防手震）與前鏡頭，約每秒 30 幀，能拍照、錄影（Beta 0.6）；第二顆後鏡頭還沒 |
| 藍牙 | 部分 | ❌ | WCN3990（UART）：iOS 能開藍牙、掃描、和 Mac 配對（`bt=4`）；**BLE 鍵盤能配對、打字**（BTLEServer）；AirPods Pro 2 能配對、播放，重開機後配對保留（Beta 0.7） |
| SSH | ✅ | ✅ | `sshd`，只收你自己的金鑰（`RC_JOBS=rc.jobs.ssh6t`）；預裝 `neofetch`，登入就顯示 |
