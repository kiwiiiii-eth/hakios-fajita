# OPiOS 16.5 (HakiOS) – OnePlus 6T: test kit (Beta 0.8.1)

OPiOS (OP for OnePlus): iOS 16.5 on a OnePlus 6T, two ways: **from the Mac** (`./run.sh`: everything in RAM, nothing flashed) or **installed**
(`./install.sh`: the phone starts iOS from its power button and keeps your data; Android stays in its other slot).

[繁體中文](#繁體中文) · [Release notes](https://github.com/kiwiiiii-eth/hakios-fajita/blob/main/releases/v0.8.1-beta.md) · [Issues](https://github.com/kiwiiiii-eth/hakios-fajita/issues)

## 1. What you need

| | |
|---|---|
| Phone | A **OnePlus 6T** (fajita; not the 6, not the T-Mobile 6T) with an **unlocked bootloader**, running OxygenOS |
| Mac | Apple silicon (tested) or Intel (untried), with [Homebrew](https://brew.sh): `brew install python sevenzip zstd coreutils android-platform-tools` |
| iOS | Apple's **iOS 16.5 IPSW for iPhone X** (iPhone10,3/10,6, build 20F66, 6.2 GB), downloaded by you, e.g. from https://ipsw.me/iPhone10,3 |
| Space | About **15 GB** free, and a USB cable |

## 2. Set up (once)

```sh
./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw   # 15–25 minutes
```

It asks for the phone once, in Android with USB debugging on, to copy its firmware; then it unpacks your IPSW and builds
the images. With a newer kit, `FW=<the old kit>/work/hakios-xnu-kernel ./setup.sh <IPSW>` takes the firmware from the old
kit instead of the phone.

## 3. Try it from the Mac

```sh
./run.sh                       # an hour (SECS=600 ./run.sh: ten minutes)
EXTRA="island=1" ./run.sh      # with the Dynamic Island; EXTRA="gnss=1": the modem's GPS (experimental)
```

The phone can be in Android or fastboot. The lock screen comes up after about 4 minutes; when the time is up iOS stops
and the phone goes back to the fastboot screen. Nothing on the phone is kept: each run starts fresh.
`fastboot oem stop` ends a run early.

## 4. Install it

```sh
./install.sh              # ISLAND=1 ./install.sh for the Dynamic Island
```

> [!WARNING]
> **The first install erases Android's data** (apps, photos, accounts): you type `ERASE` first. Android itself stays.

| Step | What `install.sh` does |
|---|---|
| 1 | Reads the partition table and both slots' boot, dtbo and vbmeta (twice, compared) and keeps them in `~/HakiOS-6T-backup/<serial>/`. **Keep that folder**: `uninstall.sh` puts the phone back from it |
| 2 | The first time only: makes a partition `darwin` from the last 32 GiB of userdata (`GIB=20…64`) and an empty data volume in it from 12 GiB on, and erases Android's data. The loader writes the new table only if nothing but userdata's end and darwin changes, and reads it back |
| 3 | Sends the iOS system image (2.6 GB), writes it into darwin and reads it back (about 3 minutes) |
| 4 | Puts HakiOS's boot image into the slot Android does not use and makes that slot active. Android's slot is not touched |

Then the phone starts iOS: a boot screen with a progress bar for about 20 seconds, the lock screen within a few minutes.
What iOS keeps (`/private/var`) is on the phone at once; shut down and restart from iOS work as on an iPhone, and a forced
restart is safe (the volume is journaled).

Options: `TARGET=a|b` the slot; `EXTRA="gnss=1"` more kernel arguments; `DEBUG=1` the loader's log on the boot screen.

## 5. Update, switch, remove

| Command | |
|---|---|
| `./install.sh` again | Updates an install: steps 3 and 4 only, nothing is erased |
| `./switch.sh android` / `./switch.sh hakios` | Starts Android / HakiOS from then on |
| `./uninstall.sh` | HakiOS off the phone: its slot and the partition table put back, userdata made again (**Android's data and darwin are erased**; `KEEP_ANDROID_DATA=1` skips that, `KEEP_DARWIN=1` leaves the table) |

## What to try

| | |
|---|---|
| Wi‑Fi, SSH | Settings → Wi‑Fi, then from the Mac on the same network: `ssh -i work/hakios-xnu-kernel/ssh/client_ed25519 root@<the phone's address>` (`neofetch` greets you) |
| Cellular data | With a SIM and Wi‑Fi off; Settings → Cellular. Read the release notes' "Cellular data: before you use it": tested with one carrier only, and it uses your plan |
| Personal Hotspot | Settings → Personal Hotspot → Allow Others to Join, or Control Center. Devices on it use your cellular data |
| Sound | Ringtones, YouTube in Safari, the volume buttons; Voice Memos records (the speaker is limited to −20 dBFS) |
| Bluetooth | Pair a Mac, AirPods or a BLE keyboard (Settings → Bluetooth). With `run.sh`, pair again every run |
| Cameras | The Camera app: the main camera and the front one, photos and videos |
| TrollStore | On the home screen; install an IPA from Files or Safari |
| Location | `gnss=1` (experimental): outdoors, Google Maps in Safari (Apple Maps needs an activated device) |

## Known issues

- The second rear camera is not used; scrolling has about one late frame in 25.
- The hotspot runs 802.11g/a (up to 54 Mbps); cellular data is tested only with FarEasTone (Taiwan), roaming not at all.
- No calls; SMS are not kept; no App Store or Apple ID. `neofetch` says "iPhone X" (the user space believes it is one).
- `./run.sh` may stop right at the start now and then (the system image sent over USB arrived damaged): run it again.

## When something goes wrong

- The logs: `work/out/logs/` for runs, `~/HakiOS-6T-backup/<serial>/logs/` for installs. Open an
  [issue](https://github.com/kiwiiiii-eth/hakios-fajita/issues) with the log, what you did and what you saw (a photo of
  the screen helps).
- **Stuck?** Hold Power + Volume Up until the fastboot screen, then `./switch.sh android` or `./install.sh` again.
  Holding Volume Down while the phone starts shows HakiOS's boot menu.

Support: [issues](https://github.com/kiwiiiii-eth/hakios-fajita/issues) · X [@0x718_718](https://x.com/0x718_718) · BTC `bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`

---

# 繁體中文

OPiOS（OP 是 OnePlus 的縮寫）讓 OnePlus 6T 跑 iOS 16.5，兩種用法：**從 Mac 開機**（`./run.sh`：全部在記憶體裡，不刷任何分區），或**安裝到手機**
（`./install.sh`：按電源鍵就進 iOS，資料存在手機上；Android 留在另一個 slot）。

[English](README.md) · [版本說明](https://github.com/kiwiiiii-eth/hakios-fajita/blob/main/releases/v0.8.1-beta.md#繁體中文) · [問題回報](https://github.com/kiwiiiii-eth/hakios-fajita/issues)

## 1. 需要準備

| | |
|---|---|
| 手機 | **已解鎖 bootloader 的 OnePlus 6T**（fajita，不是 6，也不是 T-Mobile 版 6T），系統是 OxygenOS |
| Mac | Apple Silicon（已測）或 Intel（未實測），裝好 [Homebrew](https://brew.sh) 後執行 `brew install python sevenzip zstd coreutils android-platform-tools` |
| iOS | 自己下載的 **iPhone X iOS 16.5 IPSW**（iPhone10,3/10,6，20F66，6.2 GB），例如 https://ipsw.me/iPhone10,3 |
| 空間 | 約 **15 GB**，以及一條 USB 線 |

## 2. 設定（只做一次）

```sh
./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw   # 15～25 分鐘
```

中途會請你把手機開在 Android、打開 USB 偵錯，用來複製手機的韌體；接著解開 IPSW、建好映像。換新版套件時，
`FW=<舊套件>/work/hakios-xnu-kernel ./setup.sh <IPSW>` 會從舊套件拿韌體，不用再接 Android。

## 3. 從 Mac 開機試用

```sh
./run.sh                       # 一輪 1 小時（SECS=600 ./run.sh：10 分鐘）
EXTRA="island=1" ./run.sh      # 動態島；EXTRA="gnss=1"：數據機 GPS（實驗中）
```

手機在 Android 或 fastboot 都可以。約 4 分鐘後出現鎖定畫面；時間到 iOS 會停下，手機回到 fastboot 畫面。手機上什麼都不會保留，
每一輪都是全新的。`fastboot oem stop` 可以提早結束。

## 4. 安裝到手機

```sh
./install.sh              # 要動態島：ISLAND=1 ./install.sh
```

> [!WARNING]
> **第一次安裝會清除 Android 的資料**（App、照片、帳號），要先輸入 `ERASE`。Android 系統本身會保留。

| 步驟 | `install.sh` 做什麼 |
|---|---|
| 1 | 把分區表與兩個 slot 的 boot、dtbo、vbmeta 讀兩次比對後備份到 `~/HakiOS-6T-backup/<序號>/`。**這個資料夾請留著**，解除安裝靠它 |
| 2 | 只有第一次：從 userdata 尾端切出 32 GiB 的 `darwin` 分區（`GIB=20…64`），在 12 GiB 之後建空白資料磁碟區，並清除 Android 資料。loader 只在「只改 userdata 結尾和 darwin」時才寫入，並讀回確認 |
| 3 | 送出 iOS 系統映像（2.6 GB），寫進 darwin 並讀回（約 3 分鐘） |
| 4 | 把 HakiOS 的開機映像刷進 Android 沒在用的 slot，並設為使用中。Android 那個 slot 完全不動 |

之後按電源鍵就進 iOS：約 20 秒有進度條的開機畫面，幾分鐘內出現鎖定畫面。iOS 寫的資料（`/private/var`）直接存在手機上；
iOS 裡的關機、重新開機都能用，強制重開也安全（磁碟區有日誌）。

其他選項：`TARGET=a|b` 指定 slot；`EXTRA="gnss=1"` 加核心參數；`DEBUG=1` 在開機畫面顯示 loader 記錄。

## 5. 更新、切換、移除

| 指令 | |
|---|---|
| 再跑一次 `./install.sh` | 更新已安裝的版本：只做步驟 3、4，不清任何資料 |
| `./switch.sh android`／`./switch.sh hakios` | 之後開機進 Android／HakiOS |
| `./uninstall.sh` | 移除 HakiOS：還原它的 slot 與分區表、重建 userdata（**Android 資料與 darwin 都會清除**；`KEEP_ANDROID_DATA=1` 不清，`KEEP_DARWIN=1` 保留分區表） |

## 可以試什麼

| | |
|---|---|
| Wi‑Fi、SSH | 「設定 → Wi‑Fi」連上網路，再從同網路的 Mac：`ssh -i work/hakios-xnu-kernel/ssh/client_ed25519 root@<手機 IP>`（會看到 neofetch） |
| 行動數據 | 插 SIM 卡、關掉 Wi‑Fi；「設定 → 行動服務」。使用前請先看版本說明的「行動數據：使用前請先看」：只測過一家電信商，而且會用到你的流量 |
| 個人熱點 | 「設定 → 個人熱點 → 允許其他人加入」或控制中心。連上的裝置會用到你的行動數據 |
| 聲音 | 鈴聲、Safari 裡的 YouTube、音量鍵；語音備忘錄能錄音（喇叭限制在 −20 dBFS） |
| 藍牙 | 配對 Mac、AirPods 或 BLE 鍵盤（設定 → 藍牙）。用 `run.sh` 時每一輪都要重新配對 |
| 相機 | 相機 App 的主鏡頭與前鏡頭，能拍照、錄影 |
| TrollStore | 在主畫面上；可從「檔案」或 Safari 安裝 IPA |
| 定位 | `gnss=1`（實驗中）：到戶外用 Safari 開 Google 地圖（Apple 地圖需要已啟用的裝置） |

## 已知問題

- 第二顆後鏡頭還沒用上；滑動約 25 幀有 1 幀晚到。
- 熱點是 802.11g/a（最快 54 Mbps）；行動數據只在遠傳（台灣）實測過，漫遊完全沒測。
- 不能打電話；簡訊不會保存；不能用 App Store、Apple ID。`neofetch` 顯示 iPhone X（使用者空間以為自己是 iPhone X）。
- `./run.sh` 偶爾會一開機就停（經 USB 傳過去的系統映像傳壞了）：再跑一次就好。

## 出問題時

- 記錄：從 Mac 開機在 `work/out/logs/`，安裝在 `~/HakiOS-6T-backup/<序號>/logs/`。到 [issues](https://github.com/kiwiiiii-eth/hakios-fajita/issues)
  回報，附上記錄、你做了什麼、看到什麼（拍下螢幕更好）。
- **卡住了**：按住「電源＋音量上」到 fastboot 畫面，再跑 `./switch.sh android` 或重跑 `./install.sh`。開機時按住音量下會出現 HakiOS 開機選單。

聯絡與支持：[issues](https://github.com/kiwiiiii-eth/hakios-fajita/issues)・X [@0x718_718](https://x.com/0x718_718)・捐款（BTC）`bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`
