# HakiOS on the OnePlus 6T — Beta 0.5 test kit

The Darwin (XNU) kernel and the iOS 16.5 user space on a OnePlus 6T, two ways:

- **from the Mac** (`./run.sh`, as before): booted over USB, entirely in RAM. Nothing is flashed: the phone keeps
  Android, and a reboot goes back to it.
- **installed** (`./install.sh`): the phone starts iOS by itself from its power button, no Mac, no cable. Its data
  lives on a 20 GB volume of its own on the phone (new in 0.5: Settings shows the space, and a restart takes under a
  minute). Android stays in its own slot, a command away. **Installing erases Android's data** (see below).

Release notes: https://github.com/kiwiiiii-eth/hakios-fajita/blob/main/releases/v0.5-beta.md

## You need

- A **OnePlus 6T** (fajita, not the 6 or the T-Mobile 6T) with an **unlocked bootloader**, running OxygenOS
- A **Mac** (Apple silicon, tested; Intel should work, untried) with [Homebrew](https://brew.sh), and:
  `brew install python sevenzip zstd coreutils android-platform-tools`
- **Apple's iOS 16.5 IPSW for iPhone X** (iPhone10,3/10,6, build 20F66, `iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw`,
  6.2 GB), downloaded by you, e.g. from https://ipsw.me/iPhone10,3
- About **15 GB** of free disk and a USB cable

## Two commands

```sh
./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw   # once, 15–25 minutes
./run.sh                                                               # every boot, an hour each (SECS=… for another length)
```

`setup.sh` asks for the phone once, in Android with USB debugging on, to copy its firmware. `run.sh` takes the phone
from Android or fastboot, sends the system to it and boots it; the lock screen comes up after about 4 minutes.

## Installing

```sh
./install.sh          # once, about 10 minutes; again later to update (nothing erased then; from 0.4 too)
./switch.sh android   # back to Android        ./switch.sh hakios   back to iOS
./uninstall.sh        # HakiOS off the phone, the phone as it was
```

What `install.sh` does, saying each step first:

1. Reads the phone's partition table and the boot, dtbo and vbmeta partitions of both slots (twice, compared) and keeps
   them in `~/HakiOS-6T-backup/<serial>/`. **Keep that folder**: `uninstall.sh` puts the phone back from it.
2. Makes a partition `darwin` of the last 32 GiB of userdata (`GIB=…` for 20–64; the data volume gets what is past 12 GiB). **Everything Android keeps is erased**
   — apps, photos, accounts — and Android starts as new. You type `ERASE` first. The loader writes the new table only
   if nothing but userdata's end and darwin changes, and reads it back.
   Then makes the data volume: an empty HFS Plus volume in darwin from 12 GiB on (about 20 GB), once, with macOS's own
   `newfs_hfs`; the system image and anything before 12 GiB are left as they are, and checked to be.
3. Writes the iOS system image (2.6 GB) into darwin and reads it back (about 3 minutes).
4. Puts HakiOS's boot image into the slot Android is not using, and makes that slot active. Android's own slot is not
   touched.

Then the phone starts iOS: a boot screen (HakiOS, a progress bar as the system image is read, the boot's facts
below) for about 20 seconds, and the lock screen within a few minutes. `/private/var` is the data volume: what iOS keeps
is on the phone at once, and shutting down or restarting from iOS works as on an iPhone. The first start after
installing (or updating from 0.4) moves what 0.4 kept into the volume, once. A forced restart is safe: the volume is
journaled.

- **Stuck?** Hold Power + Volume Up until the fastboot screen, then `./switch.sh android` (Android) or `./install.sh`
  again. Holding Volume Down while the phone starts shows HakiOS's boot menu.
- `uninstall.sh` puts back HakiOS's slot and the partition table, and makes userdata again (`fastboot -w`: **Android's
  data is erased again**, and everything in darwin). `KEEP_ANDROID_DATA=1` skips the erase (Android may grow back into
  the space by itself, not promised); `KEEP_DARWIN=1` leaves the table.
- Going back to Beta 0.4 (its `install.sh`) shows the data as it was when 0.5 moved it into the volume; what was written
  under 0.5 is in the volume, which 0.4 does not use.
- `DEBUG=1 ./install.sh` puts the loader's own log on the boot screen instead of the boot's facts.

## What to try

- Swipe up; Settings → Wi-Fi to join a network (every boot). Then from the Mac, on the same network:
  `ssh -i work/hakios-xnu-kernel/ssh/client_ed25519 root@<the phone's address>` — `neofetch` greets you.
  If the Mac cannot reach the phone (some routers isolate their clients), put both on an iPhone's hotspot.
- Sound: Settings → Sounds & Haptics → Ringtone; YouTube in Safari; the volume buttons. (The speaker is limited to −20 dBFS.)
- The microphone: record in Voice Memos and play it back.
- With a SIM: LTE data with Wi-Fi off. Bluetooth: scan, pair with a Mac; pair a BLE keyboard (Settings → Bluetooth) and
  type in Notes. Pair again after every boot.
- The flashlight and brightness from Control Center.
- Safari: open any site (pages load as of Beta 0.3). Wi-Fi off and on in Settings: the network is joined again by itself.
- Location (experimental): `EXTRA="gnss=1" ./run.sh` (or an install image built with `EXTRA="gnss=1"`), outdoors with a
  view of the sky, then Google Maps in Safari (Apple Maps needs an activated device and shows no map). Location
  Services turn on by themselves; satellites are seen even indoors. Reports welcome: an outdoor GPS fix is not yet confirmed.

## When something goes wrong

Every run's log is in `work/out/logs/`. Open an issue at https://github.com/kiwiiiii-eth/hakios-fajita/issues with the
log, what you did and what you saw (a photo of the screen helps). `fastboot oem stop` ends a run early; holding power
for about 15 seconds restarts the phone into Android.

Support: issues at https://github.com/kiwiiiii-eth/hakios-fajita/issues; X [@0x718_718](https://x.com/0x718_718); donations (BTC) `bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`.

Known: no cameras; with `run.sh` nothing on the phone survives a reboot (install for that); Bluetooth pairings are lost
at every boot; scrolling is not yet smooth (55-60 frames a second, about one in ten late); `neofetch` says "iPhone X"
because the user space believes it is one.

---

# 繁體中文

Darwin（XNU）核心＋iOS 16.5 使用者空間跑在 OnePlus 6T 上（Beta 0.5），兩種用法：

- **從 Mac 開機**（`./run.sh`，同以前）：透過 USB 開機，整套系統在記憶體裡，**不刷任何分區**，重開機就回到 Android。
- **安裝到手機**（`./install.sh`）：按電源鍵就直接開進 iOS，不用 Mac、不用接線。資料存在手機上一個約 20 GB 的磁碟區（0.5 新增：設定裡看得到完整容量，重開不到 1 分鐘）。
  Android 留在自己的 slot，一個指令就能切回去。**安裝會清除 Android 的資料**（見下方）。

**需要準備**：
- 已解鎖 bootloader 的 OnePlus 6T（OxygenOS）。
- Mac（Apple Silicon 已測；Intel 應可用，未實測），裝好 Homebrew 後執行 `brew install python sevenzip zstd coreutils android-platform-tools`。
- 自己下載的 iPhone X iOS 16.5 IPSW（20F66，6.2 GB）。
- 約 15 GB 空間。

**兩個指令**：
- `./setup.sh <IPSW 路徑>`：只跑一次，15～25 分鐘。中途會請你把手機開在 Android、開啟 USB 偵錯，用來抽韌體。
- `./run.sh`：每次開機都跑，一輪 60 分鐘（`SECS=秒數` 可改），約 4 分鐘後出現鎖定畫面；時間到 iOS 會停下，手機自動回到 fastboot 畫面。

**安裝到手機**：
- `./install.sh`：第一次約 10 分鐘；之後再跑一次就是更新，不會清任何資料。
- 它會：①把分區表與兩個 slot 的 boot／dtbo／vbmeta 讀兩次比對後備份到 `~/HakiOS-6T-backup/<序號>/`（**這個資料夾請留著**，
  解除安裝靠它）②從 userdata 尾端切出 32 GiB 的 `darwin` 分區（`GIB=…` 可改 20～64；資料磁碟區是 12 GiB 之後的部分），**Android 的資料會全部清除**，
  要先輸入 `ERASE`；loader 只在「只改 userdata 結尾和 darwin」時才寫入，並讀回確認 ③把 iOS 系統映像寫進 darwin 並讀回（約 3 分鐘）
  之後建立資料磁碟區：darwin 12 GiB 之後約 20 GB 的空白 HFS+（只做一次，用 macOS 內建的 `newfs_hfs`；系統映像與 12 GiB 之前的內容不動，並會檢查確認）
  ④把 HakiOS 的開機映像刷進 Android 沒在用的 slot，並設為使用中。Android 那個 slot 完全不動。
- 之後按電源鍵就進 iOS：先是約 20 秒的開機畫面（HakiOS、讀取系統映像的進度條、底下的開機資訊），幾分鐘內出現鎖定畫面。`/private/var` 就是資料磁碟區，寫入直接存在手機上；iOS 裡的關機、重新開機都能用，強制重開也安全（有日誌）。安裝或從 0.4 更新後的第一次開機，會把 0.4 存的資料搬進磁碟區（只搬一次）。
- `./switch.sh android` 切回 Android，`./switch.sh hakios` 切回 iOS。
- **卡住了**：按住「電源＋音量上」到 fastboot 畫面，再跑 `./switch.sh android` 或重跑 `./install.sh`；開機時按住音量下會出現 HakiOS 開機選單。
- `./uninstall.sh`：還原 HakiOS 的 slot 與分區表，並重建 userdata（**Android 資料與 darwin 內容都會清除**）；
  `KEEP_ANDROID_DATA=1` 不清 Android 資料（空間可能由 Android 自己長回來，不保證）；`KEEP_DARWIN=1` 不動分區表。
- 退回 0.4（用 0.4 的 `install.sh`）會看到搬進磁碟區當時的資料；在 0.5 寫的資料在磁碟區裡，0.4 不會用到。
- `DEBUG=1 ./install.sh`：開機畫面底下改顯示 loader 的原始記錄。

**可以測**：
- **Wi‑Fi 與 SSH**：每次開機都要在「設定 → Wi‑Fi」重新加入網路。接著從 Mac 執行 `ssh -i work/hakios-xnu-kernel/ssh/client_ed25519 root@<手機 IP>`，會看到 neofetch；連不到就讓兩台都連 iPhone 熱點。
- **聲音**：鈴聲、YouTube、音量鍵。
- **麥克風**：用語音備忘錄錄音再播放。
- **行動網路**：插 SIM 卡後關掉 Wi‑Fi，用 LTE 上網。
- **藍牙**：掃描、和 Mac 配對；在「設定 → 藍牙」配對 BLE 鍵盤，到備忘錄打字（每次開機都要重新配對）。
- **控制中心**：手電筒、亮度。
- **Safari**：開任何網站（Beta 0.3 起能載入）。在設定把 Wi‑Fi 關掉再打開，會自動連回剛才的網路。
- **定位（實驗中）**：`EXTRA="gnss=1" ./run.sh`（或打包安裝映像時帶 `EXTRA="gnss=1"`），到戶外看得到天空的地方，用 Safari 開 Google 地圖（Apple 地圖需要已啟用的裝置，不會顯示圖資）。定位服務會自動打開，室內就能看到衛星。戶外 GPS 定位還沒確認，歡迎回報。

**回報問題**：到 GitHub issues，附上 `work/out/logs/` 的紀錄、你做了什麼、看到什麼。

**聯絡與支持**：GitHub issues；X [@0x718_718](https://x.com/0x718_718)；捐款（BTC）`bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`。

**其他**：`fastboot oem stop` 可以提早結束一輪；長按電源鍵約 15 秒會重開回 Android。

**已知問題**：沒有相機；用 `run.sh` 開機時資料不會保留（要保留請安裝）；藍牙配對每次開機都要重來；滑動還不夠順（每秒 55～60 幀，約一成的幀會晚到）；`neofetch` 顯示 iPhone X。
