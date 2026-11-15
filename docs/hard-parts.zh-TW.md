# 最難的幾關

[← README](../README.zh-TW.md) · [開機流程](how-it-boots.zh-TW.md) · [硬體支援](hardware.zh-TW.md) · [最難的幾關](hard-parts.zh-TW.md) · [從原始碼建置](building.zh-TW.md) · [更新紀錄](../CHANGELOG.zh-TW.md) · [English](hard-parts.md)

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
| 設定顯示手機只有 1 GB | `/private/var` 是記憶體檔案系統（RAM 的四分之一），關機時打包存進 `darwin` | 在 `darwin` 存檔槽之後放一個 HFS+ 磁碟區；舊存檔只搬一次，而且只在完整讀回時才算數 |
| 「iPhone 儲存空間」是空的 | 它算的是根目錄的空間，而根目錄是唯讀的系統映像（2.6 GB、0 可用） | 根目錄改回報資料磁碟區的空間（`vfs_getattr`），跟真 iPhone 根目錄共用容器空間一樣 |
| 強制重開後時鐘倒退好幾小時 | 從卡住的 loader 強制重開時，PMIC 的 RTC 計數會歸零，保存的差值就指向好幾小時前 | 差值連同當時的計數一起保存；計數變小或時間會往回撥時，就不動時鐘 |
| 電信商名稱顯示成四個方塊 | iOS 用蘋方的 Medium 字重畫電信商名稱，裁剪過的系統字型把它拿掉了 | 保留 Medium |
