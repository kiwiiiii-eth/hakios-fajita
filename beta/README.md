# HakiOS on the OnePlus 6T — Beta 0.1 test kit

The Darwin (XNU) kernel and the iOS 16.5 user space on a OnePlus 6T, booted from a Mac over USB, entirely in RAM.
Nothing is flashed: the phone keeps Android, and a reboot goes back to it.
Release notes: https://github.com/kiwiiiii-eth/hakios-fajita/blob/main/releases/v0.1-beta.md

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
./run.sh                                                               # every boot, 15 minutes each
```

`setup.sh` asks for the phone once, in Android with USB debugging on, to copy its firmware. `run.sh` takes the phone
from Android or fastboot, sends the system to it and boots it; the lock screen comes up after about 4 minutes.

## What to try

- Swipe up; Settings → Wi-Fi to join a network (every boot). Then from the Mac, on the same network:
  `ssh -i work/hakios-xnu-kernel/ssh/client_ed25519 root@<the phone's address>` — `neofetch` greets you.
  If the Mac cannot reach the phone (some routers isolate their clients), put both on an iPhone's hotspot.
- Sound: Settings → Sounds & Haptics → Ringtone; YouTube in Safari; the volume buttons. (The speaker is limited to −20 dBFS.)
- With a SIM: LTE data with Wi-Fi off. Bluetooth: scan, pair with a Mac.
- The flashlight and brightness from Control Center.

## When something goes wrong

Every run's log is in `work/out/logs/`. Open an issue at https://github.com/kiwiiiii-eth/hakios-fajita/issues with the
log, what you did and what you saw (a photo of the screen helps). `fastboot oem stop` ends a run early; holding power
for about 15 seconds restarts the phone into Android.

Support: issues at https://github.com/kiwiiiii-eth/hakios-fajita/issues; X [@0x718_718](https://x.com/0x718_718); donations (BTC) `bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`.

Known: no microphone, cameras or storage that survives a reboot; BLE keyboards pair but do not type; `neofetch` says
"iPhone X" because the user space believes it is one.

---

# 繁體中文

Darwin（XNU）核心＋iOS 16.5 使用者空間跑在 OnePlus 6T 上。由 Mac 透過 USB 開機，整套系統在記憶體裡，**不刷任何分區**，
重開機就回到 Android。

**需要準備**：
- 已解鎖 bootloader 的 OnePlus 6T（OxygenOS）。
- Mac（Apple Silicon 已測；Intel 應可用，未實測），裝好 Homebrew 後執行 `brew install python sevenzip zstd coreutils android-platform-tools`。
- 自己下載的 iPhone X iOS 16.5 IPSW（20F66，6.2 GB）。
- 約 15 GB 空間。

**兩個指令**：
- `./setup.sh <IPSW 路徑>`：只跑一次，15～25 分鐘。中途會請你把手機開在 Android、開啟 USB 偵錯，用來抽韌體。
- `./run.sh`：每次開機都跑，一輪 15 分鐘，約 4 分鐘後出現鎖定畫面。

**可以測**：
- **Wi‑Fi 與 SSH**：每次開機都要在「設定 → Wi‑Fi」重新加入網路。接著從 Mac 執行 `ssh -i work/hakios-xnu-kernel/ssh/client_ed25519 root@<手機 IP>`，會看到 neofetch；連不到就讓兩台都連 iPhone 熱點。
- **聲音**：鈴聲、YouTube、音量鍵。
- **行動網路**：插 SIM 卡後關掉 Wi‑Fi，用 LTE 上網。
- **藍牙**：掃描、和 Mac 配對。
- **控制中心**：手電筒、亮度。

**回報問題**：到 GitHub issues，附上 `work/out/logs/` 的紀錄、你做了什麼、看到什麼。

**聯絡與支持**：GitHub issues；X [@0x718_718](https://x.com/0x718_718)；捐款（BTC）`bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`。

**其他**：`fastboot oem stop` 可以提早結束一輪；長按電源鍵約 15 秒會重開回 Android。
