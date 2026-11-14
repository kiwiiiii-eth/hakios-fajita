# HakiOS on the OnePlus 6T (`fajita`)

**The Darwin (XNU) kernel and the iOS 16.5 user space, running on a OnePlus 6T (Snapdragon 845).**
It boots to the home screen with the GPU, touch, Wi-Fi, **LTE data**, **sound from the speaker**, **the microphone**, Bluetooth
(**BLE keyboards type**), charging, vibration and the flashlight working, entirely from RAM. Safari loads pages, and Wi-Fi
joins a known network again by itself.

**Current release: Beta 0.3 (`v0.3-beta`, November 2026)** — see [the release notes](releases/v0.3-beta.md) and
[testing Beta 0.3](#testing-beta-03).

This is a device port of [HakiOS](https://github.com/oosexgang/hakios-xnu-kernel), which ports the open-source XNU kernel to
Qualcomm phones. The upstream reference phone is the POCO X5 Pro (Snapdragon 778G). The 6T is a different SoC generation, so
the GPU, modem, IPA, Wi-Fi, touch, battery, brightness, flash and haptic drivers had to be written or ported for it.

[繁體中文說明](README.zh-TW.md)

> **Not affiliated with Apple, OnePlus or Qualcomm.** No Apple software, no iOS image and no vendor firmware are in
> this repository. You download the IPSW from Apple yourself and take the firmware from your own phone. Whether you may
> use them this way is up to you (see upstream's [LEGAL.md](https://github.com/oosexgang/hakios-xnu-kernel/blob/main/LEGAL.md)).
> Apple's services (activation, Apple ID, App Store) are not supported and are not a goal.

## What works

As seen on the phone in November 2026 (the full list is in [`device.conf`](device.conf)):

| Area | 6T | Upstream reference (redwood) | Notes |
|---|---|---|---|
| Lock screen, home screen, stock apps | ✅ | ✅ | SpringBoard, Settings, Safari (pages load: Beta 0.3), Health … |
| Touch, buttons | ✅ | ✅ | Synaptics S3706B (RMI4 over I2C), written for the 6T; read 120 times a second |
| All 8 CPU cores, frequency scaling | ✅ | ✅ | SDM845 OSM tables, load governor |
| GPU (OpenGL ES 3.2 via Mesa) | ✅ | ✅ | **Adreno 630 brought up from cold**, up to 60 fps |
| Wi-Fi | ✅ | ✅ | WCN3990 + Linux ath10k; join from Settings, **5 GHz ≈ 95–110 Mbps**; a known network is joined again by itself (auto-join) |
| Battery level | ✅ | ✅ | PMI8998 fuel gauge in the status bar |
| **Charging under this kernel** | ✅ | ❌ | 41 % → 64 % in one session, 1 A from USB |
| **Cellular: LTE registration and data** | ✅ | partial (no registration) | FarEasTone LTE, 4 bars; Safari over LTE, 88 MB down / 56 MB up with zero IPA errors (`ipa8=11`) |
| **Flashlight** | ✅ | partial | From Control Center's button |
| **Screen brightness** | ✅ | — | Settings and Control Center slider (DSI command mode) |
| Temperature guard | ✅ | partial | 21 sensors, GPU and CPU scale down with load |
| Vibration | ✅ | ✅ | PMI8998 LRA, on by default (stronger than an iPhone's; to be tuned) |
| Storage | partial | ✅ | `/private/var` kept across reboots in a partition `darwin` cut from userdata (developer setups; the test kit does not make it yet) |
| Location | partial | — | The modem's GPS (QMI LOC) to Location Services (`gnss=1`); plumbing done, an outdoor fix not yet confirmed |
| **Sound (speaker)** | ✅ | ✅ | iOS sounds, keyboard clicks, YouTube: ADSP → I2S → TFA9894 amplifier (bypass); limited to −20 dBFS for the speaker's safety; on by default |
| **Microphone** | ✅ | ✅ | Voice Memos records: the bottom microphone (AMIC4) → WCD9340 codec → SLIMbus → ADSP; powered only while something records |
| Cameras | ❌ | ✅ | Not started |
| Bluetooth | partial | ❌ | WCN3990 over UART: iOS turns Bluetooth on, scans and pairs with a Mac (`bt=4`); **BLE keyboards pair and type** (BTLEServer, HID over GATT); pairings are not kept across reboots |
| SSH | ✅ | ✅ | `sshd` with your own key (`RC_JOBS=rc.jobs.ssh6t`); `neofetch` preinstalled and shown at login |

## How it boots

Nothing is flashed. A reboot brings the phone back to its own Android.

```
ABL (stock bootloader)  ── fastboot boot ──▶  U-Boot  ── hakios load ──▶  HakiOS loader (UEFI app)
      ▲                                                                       │  stages the system image in RAM
      └─ reboot reason set in the PMIC so every reset returns to fastboot      ▼
                                                                    XNU 8796 ─▶ launchd ─▶ SpringBoard
```

**What is written to the phone:** one PMIC register (the reboot reason `0x88f`, so a reset lands in fastboot). While the
system runs, the charger's input and current limits, the flash LED and the haptic block, each limited to a register
allow-list and read back after every write. No partition is written: `persist`, `modemst*`, `fsg`, `xbl`, `abl` and `tz`
are never touched. The modem's file system is served read-only from a copy in RAM. With `ipa8=11`, two of the modem's data
settings (data switch on, default data SIM) are changed in the modem's memory only, not in its partitions.

## The hard parts

The bugs that took the longest, written down for the next SDM845 port:

| Problem | Cause | Fix |
|---|---|---|
| The kernel stopped right after the framebuffer came up | XNU hard-codes the EL1 virtual timer as interrupt 27; on SDM845 it is **19** | `gic_vtimer=` boot argument (`CONFIG_GIC_VTIMER=19` in `soc/configs/sdm845.config`) |
| Touch only worked with the USB cable unplugged | USB noise; the controller has a "charger connected" bit (F01 ctrl0 bit 5) | The driver reads USBIN from the PMIC every 0.5 s and sets the bit |
| GMU powered the GPU but never set the PLL | The A630's GMU firmware wants chip ID **0x06030200** (630.2), not the device tree's 0x06030000; RSCC/PDC must be programmed *before* the GMU starts | Both fixed; then DCVS votes, without which every GPU wait took 70–185 ms |
| The phone crashed to Qualcomm CrashDump 0.4 s after the modem's MBA got its header | Read the TrustZone diag log out of a CrashDump with EDL: a **NoC error** at `QDSP6SS_SLEEP`. Our own debug read touched QDSP6SS after the MBA had locked it with an XPU | No QDSP6SS access after the header is handed over (Linux never reads it either) |
| Modem up, but no Wi-Fi firmware service | The modem asserted when we pre-allocated the IPA SMEM item or mentioned IPA at all | GLINK SMEM items 478/479 allocated as Linux does, IPA left out entirely |
| Wi-Fi WMI timeouts, now and then | A NAPI poll racing the interrupt: a schedule arriving mid-poll was dropped and that copy engine's interrupt stayed masked | Linux's "missed" semantics in our NAPI |
| Joined, WPA2 done, but stuck at 169.254 | The `lx_transmit` entry point was still a placeholder returning `ENETDOWN` | Wired to the station's send path; DHCP, Safari |
| Battery drained while plugged in | ABL leaves the input limit at 500 mA and the charge current at **0** | Set both to 1 A (with read-back and a 45 °C cut-off) |
| Wi-Fi died about 2 minutes after LTE registered | The modem asserted in its LTE downlink (`ipa_dl_opt_lte.c: IPA Assert new_free_space > 0`): with no IPA set up it had nowhere to put packets, and the Wi-Fi firmware runs on the modem | Bring up the IPA; until it is, the modem stays offline by default |
| QCOM CrashDump right after TrustZone started the IPA firmware | The IPA init we started from writes **IPA v4.11** register offsets; the SDM845 has **v3.5.1**, the writes land elsewhere and hang the bus. Before that, TrustZone refused a `.mdt` that kept the mbn's padding between the program headers and the hash segment | v3.5.1 layouts throughout; a tight `.mdt`; Linux's bus votes before the authentication |
| Registered on LTE, but every data call refused with "no service" | Left in the modem from Android: the data switch **off** and the default data SIM on **slot 2** | Two DSD writes (with consent, in the modem's memory only); the SIM provisioned as postmarketOS does it, without a slot switch |
| Safari's pages spun for ever, though the network worked | `mobileactivationd` traps at every start on this phone and never answers what is queued for it; `apsd` asks it while starting, `amsaccountsd` asks `apsd`, and Safari's main thread waited on AppleMediaServices (found with a stackshot of Safari's threads) | The daemon is left out (`mkjobs.py` DENY); everything that asks it gets its error at once |
| A known Wi-Fi network was never joined again by itself | wifid reads the auto-join RSSI floor once from the driver (`APPLE80211_IOC_RSSI_BOUNDS`); refused, the floor stayed **0 dBm** and every network was "Below minimum RSSI threshold" — found by disassembling `wifid` | The driver answers it (-90 / -20 dBm, floor -80); and a power-on asked for before the radio is up is taken, not refused |

## Repositories

| Repository | What |
|---|---|
| **this one** (`hakios-fajita`) | The device: configs, SoC layer (`soc/`, sdm845), U-Boot board files and patch, scripts, status |
| [`kiwiiiii-eth/hakios-xnu-kernel`](https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/fajita), branch **`fajita`** | The kernel and every new driver: `drivers/gpu/hakios.a630.c`, `hakios.dsibl.c`, `drivers/modem/hakios.mpss845.c`, `drivers/wifi/hakios.wifi10.c` + `wifi/lx/src10/`, `drivers/modem/hakios.ipa.c` (IPA 3.5.1), `drivers/input/hakios.rmi4.c`, `drivers/power/hakios.fg8998.c`, `drivers/camera/hakios.torch8998.c`, `drivers/haptic/hakios.haptic8998.c`, `drivers/audio/hakios.adsp845.c`, `drivers/bluetooth/hakios.bt3990.c` |
| [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel) | Upstream HakiOS: the XNU port, loader, user space, tools, docs |
| [`oosexgang/hakios-uefi`](https://github.com/oosexgang/hakios-uefi/tree/mac), branch `mac` | HakiOS's U-Boot patch (`u-boot/`) this port's U-Boot is built with |

## Building and running

This is a developer bring-up, not an installable ROM. You need a OnePlus 6T with an **unlocked bootloader**, a Mac (Apple
silicon; the kernel builds with Xcode), and upstream's [Building from source](https://github.com/oosexgang/hakios-xnu-kernel/blob/main/docs/getting-started/building.md)
for the general steps. What is specific to the 6T:

```sh
mkdir hakios && cd hakios
git clone -b fajita https://github.com/kiwiiiii-eth/hakios-xnu-kernel
git clone https://github.com/kiwiiiii-eth/hakios-fajita
ln -s ../../hakios-fajita hakios-xnu-kernel/devices/fajita
export PATH=$PWD/hakios-fajita/hostbin:$PATH      # macOS stand-ins for lld-link, llvm-ar, GNU sha256sum, bison, 7z

cd hakios-xnu-kernel
make fajita_defconfig && PYTHONSAFEPATH=1 make kernel   # the kernel with the 6T's drivers (see the note below)
xnuloader/mkidentity.sh && xnuloader/build.sh      # the loader
sysimage/unpack.sh ~/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw   # YOUR IPSW, downloaded from Apple
tools/mk-mesa.sh && tools/mk-ath11k.sh fetch && tools/mk-ath10k.sh  # Mesa (GPU), Linux's ath10k (Wi-Fi)
GL=1 REST=1 MODEM=1 SYSTEM=1 userland/build.sh     # root.apfs and system.apfs, with Mesa and the Wi-Fi firmware
cd ..

hakios-fajita/scripts/mk-usbimg.sh                 # U-Boot + loader, packed for ABL: out/hakios-fajita-usb.img
hakios-fajita/scripts/run-darwin-live.sh           # phone in fastboot: boot, stage the system, run, fetch the log
```

`PYTHONSAFEPATH=1`: with Homebrew's Python 3.15, XNU's own `tools/lldbmacros/core/collections.py` shadows the standard
library while the build checks the lldb macros, and a first build fails; this keeps the script's directory off `sys.path`.
The first `make kernel` also fetches Apple's XNU source and the SDKs (a few minutes); later ones take about a minute.

`run-darwin-live.sh` takes the phone from any state (U-Boot, loader, ABL) back to ABL fastboot, boots the loader, sends the
2.4 GB system image over USB (about a minute), starts the kernel and copies the log to `out/logs/` while it runs. Extra boot
arguments go in the third parameter. Set `ABL_SERIAL` if more than one device is in fastboot. The script comments are in
Traditional Chinese.

### Firmware

Never committed. It goes into `hakios-xnu-kernel/fw-gpu/` and `fw-modem/`, which git ignores:

| For | Files | From |
|---|---|---|
| GPU | `a630_gmu.bin`, `a630_sqe.fw` | linux-firmware (`qcom/`) |
| GPU | `a630_zap.mdt` + `.bXX` | your phone (signed for its TrustZone) |
| Modem | `mba.mbn`, `modem.mdt` + `.bXX` | your phone's `modem_a` partition |
| Modem, Wi-Fi | the whole `image/` directory (`wlanmdsp.mbn`, `bdwlan.*`, `*.jsn`) → `fw-modem/image/` | your phone (`/vendor/firmware_mnt/image`) |
| Wi-Fi | `ath10k/WCN3990/hw1.0/firmware-5.bin`, `board-2.bin` → `fw-modem/ath10k/` | linux-firmware |

### U-Boot

`prebuilt/u-boot.bin` is U-Boot (GPL-2.0+). Its corresponding source is U-Boot **v2026.07**, plus HakiOS's patch and files
from [`oosexgang/hakios-uefi@1c65228`](https://github.com/oosexgang/hakios-uefi/tree/1c6522893266157506c767e2ca427053ed3634a8/u-boot),
plus this repository's `u-boot/files/` and `u-boot/patches/sdm845-carveout.patch`. `scripts/fetch-uboot.sh` and
`scripts/build-uboot-vm.sh` rebuild it in a Linux VM (`aarch64-linux-gnu-`).

## Testing Beta 0.3

The easy way is the **test kit** on the [Beta 0.3 release](https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.3-beta):
the kernel, the loader and our programs prebuilt, so no Xcode is needed. You bring a OnePlus 6T with an unlocked bootloader
(nothing is flashed: Android stays), a Mac (Apple silicon; Intel should work, untried) with [Homebrew](https://brew.sh), and Apple's iOS 16.5 IPSW for iPhone X (20F66):

```sh
brew install python sevenzip zstd coreutils android-platform-tools
tar xzf hakios-6t-v0.3-beta.tar.gz && cd hakios-6t-v0.3-beta
./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw   # once: firmware from your phone over adb, your IPSW, the images
./run.sh                                                               # every boot: a 15-minute run
```

What it does, step by step, and what to try once the lock screen is up: the kit's [README](beta/README.md). The loader
in the kit carries no device identity; `setup.sh` writes the one from your own IPSW into it (`xnuloader/mkidentity.py --fill`).
To build everything from source instead, follow "Building and running" with `BT=1 GL=1 REST=1 MODEM=1 SYSTEM=1
RC=rc.launchd.aks RC_JOBS=rc.jobs.ssh6t userland/build.sh`, your own SSH keys in `hakios-xnu-kernel/ssh/` and
`make firmware` (this repository's `pull-firmware.sh`).

The log of each run is written to `out/logs/` while it runs; attach it to an issue when something goes wrong.

## Contact and support

- Issues and reports: https://github.com/kiwiiiii-eth/hakios-fajita/issues
- X: [@0x718_718](https://x.com/0x718_718)
- Donations (BTC): `bc1p6n329lsup5kpyemsvhqen70h0a4nc2ujyxflza5tfw6a4j8r4afq47gf58`

## Credits

- **[HakiOS](https://github.com/oosexgang/hakios-xnu-kernel)** (oosexgang and contributors): the XNU port, the loader,
  the user space and tooling this port stands on, and the redwood drivers the 6T's were modelled on.
- **[ios-fajita](https://github.com/edi194/ios-fajita)** by edi194, built on [ios-sweet](https://github.com/dipa-studio/ios-sweet):
  the first iOS on this phone (software rendering, October 2026); its boot image parameters and the touch controller's
  measured init sequence. This port started as [a fork of it](https://github.com/kiwiiiii-eth/ios-fajita) and moved to HakiOS
  when reading the UFS stalled.
- **[postmarketOS](https://postmarketos.org) and mainline Linux** for SDM845: the control experiment that showed the modem
  boots with the same firmware, and the reference for every rewrite (`a6xx_gmu`, `qcom_q6v5_mss`, `rmi4`, `qcom-fg`, …).
  ath10k (ISC) is compiled unchanged on LinuxKPI.
- [LineageOS](https://github.com/LineageOS/android_kernel_oneplus_sdm845) OnePlus SDM845 kernel, [Mesa](https://mesa3d.org)
  freedreno, [U-Boot](https://u-boot.org), [bkerler/edl](https://github.com/bkerler/edl).

## License

Our own files here (configs, scripts, docs, `hostbin/`) are MIT ([LICENSE](LICENSE)). `u-boot/` and `prebuilt/u-boot.bin` are
GPL-2.0+ (U-Boot), the device tree source GPL-2.0, `prebuilt/mkbootimg.py` Apache-2.0 (AOSP). The kernel drivers live in
`hakios-xnu-kernel` under its terms (XNU-derived code APSL 2.0, the rest MIT).
