# Building from source

[← README](../README.md) · [How it boots](how-it-boots.md) · [Hardware support](hardware.md) · [The hard parts](hard-parts.md) · [Building from source](building.md) · [Changelog](../CHANGELOG.md) · [繁體中文](building.zh-TW.md)

## Repositories

| Repository | What |
|---|---|
| **this one** (`hakios-fajita`) | The device: configs, SoC layer (`soc/`, sdm845), U-Boot board files and patch, scripts, status |
| [`kiwiiiii-eth/hakios-xnu-kernel`](https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/fajita), branch **`fajita`** | The kernel and every new driver: `drivers/gpu/hakios.a630.c`, `hakios.dsibl.c`, `drivers/modem/hakios.mpss845.c`, `drivers/wifi/hakios.wifi10.c` + `wifi/lx/src10/`, `drivers/modem/hakios.ipa.c` (IPA 3.5.1), `drivers/input/hakios.rmi4.c`, `drivers/power/hakios.fg8998.c`, `drivers/camera/hakios.torch8998.c`, `drivers/haptic/hakios.haptic8998.c`, `drivers/audio/hakios.adsp845.c`, `drivers/bluetooth/hakios.bt3990.c`; the loader's partition-table rules and boot screen (`xnuloader/gpt.c`, `bootscreen.c`) |
| [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel) | Upstream HakiOS: the XNU port, loader, user space, tools, docs |
| [`oosexgang/hakios-uefi`](https://github.com/oosexgang/hakios-uefi/tree/mac), branch `mac` | HakiOS's U-Boot patch (`u-boot/`) this port's U-Boot is built with |

## Building and running

This is still a developer bring-up. You need a OnePlus 6T with an **unlocked bootloader**, a Mac (Apple
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
LOCKDOWN=1 ALLOW="locationd lockdown CommCenter" GL=1 REST=1 MODEM=1 SYSTEM=1 userland/build.sh  # root.apfs, system.apfs
cd ..

hakios-fajita/scripts/mk-usbimg.sh                 # U-Boot + loader, packed for ABL: out/hakios-fajita-usb.img
hakios-fajita/scripts/run-darwin-live.sh           # phone in fastboot: boot, stage the system, run, fetch the log
WORK=$PWD hakios-fajita/beta/install.sh            # or install it (ERASES ANDROID'S DATA: see beta/README.md)
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
`scripts/build-uboot-vm.sh` rebuild it in a Linux VM (`aarch64-linux-gnu-`). `prebuilt/u-boot-install.bin` is the same
U-Boot built with `hakios_fajita_install_defconfig` (the installed environment: nothing of its own on the screen, the
reboot reason cleared before the loader, ABL's fastboot if the loader comes back).

## The test kit's build, from source

The test kit is built from these trees with `scripts/mk-beta-kit.sh`. To build what it carries yourself, follow
"Building and running" with `LOCKDOWN=1 ALLOW="locationd lockdown CommCenter" BT=1 GL=1 REST=1 MODEM=1 SYSTEM=1 RC=rc.launchd.aks
RC_JOBS=rc.jobs.ssh6t userland/build.sh` (CommCenter runs the cellular data since Beta 0.8: without `ALLOW=... CommCenter`, no data),
your own SSH keys in `hakios-xnu-kernel/ssh/` and `make firmware` (this repository's `pull-firmware.sh`). The loader in the
kit carries no device identity; `setup.sh` writes the one from your own IPSW into it (`xnuloader/mkidentity.py --fill`).
