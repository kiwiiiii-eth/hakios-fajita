# Notices

Not affiliated with Apple, OnePlus or Qualcomm. This kit contains no Apple software, no part of any IPSW and no vendor
firmware: the system image is made on your Mac from the IPSW you download, the firmware is copied from your own phone,
and the loader carries no device identity until `setup.sh` writes the one from your IPSW into it. Whether you may use
them this way is up to you (see https://github.com/oosexgang/hakios-xnu-kernel/blob/main/LEGAL.md). Apple's services
(activation, Apple ID, App Store) are not supported.

| In the kit | What | Licence | Source |
|---|---|---|---|
| `prebuilt/hakios-kernel` | XNU with HakiOS's and this port's drivers | APSL-2.0 (XNU); the drivers' own licences; Linux's ath10k under ISC | https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/fajita-v0.1-beta and Apple's xnu-8796.121.2 |
| `prebuilt/loader.blank.efi` | HakiOS's UEFI loader, blank identity | HakiOS's licence | same, `xnuloader/` |
| `prebuilt/userland/*` (but one) | HakiOS's user-space programs | HakiOS's licence | same, `userland/src/` |
| `prebuilt/userland/libOSMesa.8.dylib` | Mesa (OSMesa, freedreno) | MIT | https://mesa3d.org; HakiOS's patches in `tools/mesa/` |
| U-Boot (packed by `setup.sh` from `hakios-fajita/prebuilt/u-boot.bin`) | the boot loader `fastboot boot` starts | GPL-2.0+ | see hakios-fajita's README, "U-Boot" |

`setup.sh` also fetches, from their own sites: the two repositories at this release's tags (GitHub), linux-firmware's
`a630_gmu.bin`, `a630_sqe.fw` and ath10k's WCN3990 files (git.kernel.org; their licences in linux-firmware's
`LICENSE.qcom` and `LICENSE.QualcommAtheros_ath10k`), and the Procursus bootstrap (https://procurs.us; each package
under its own licence).
