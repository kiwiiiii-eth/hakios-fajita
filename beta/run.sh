#!/bin/bash
# HakiOS on the OnePlus 6T, Beta 0.3: one run. The phone on USB, in Android, fastboot or the loader: it is taken to the
# loader, the 2.6 GB system image is sent over USB (about a minute), and the kernel runs for SECS seconds (15 minutes by
# default); then the phone goes back to fastboot. The log is written to work/out/logs/ while it runs.
#
#   ./run.sh                 a 15-minute run
#   SECS=600 ./run.sh        a 10-minute one
#   EXTRA="gnss=1" ./run.sh  with more kernel arguments: gnss=1 turns the modem's GPS on and hands its positions to
#                            Location Services (outdoors; not yet confirmed with a fix)
#   fastboot oem stop        (from another terminal) ends a run early, in order
set -e
KIT=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-$KIT/work}
K=$WORK/hakios-xnu-kernel
[ -f "$K/userland/system.apfs" ] && [ -f "$WORK/out/hakios-fajita-usb.img" ] || { echo "run.sh: run ./setup.sh first" >&2; exit 1; }
export PATH="$WORK/hakios-fajita/hostbin:$PATH"
# the kernel's version string (hakios_kver) for a tree that is not a git checkout: without a part after the SoC's name the 6T's
# UFS driver does not know its phone ("-sdm845-", hakios.ufs.c), and every program run through dyld died of SIGBUS (run 108)
export HAKIOS_VERSION_SUFFIX=${HAKIOS_VERSION_SUFFIX:--v0.3-beta}
NAME=${NAME:-run-$(date +%m%d-%H%M)}
# a phone in Android: into the boot loader first (with USB debugging on; otherwise hold power + volume down)
if adb get-state 2>/dev/null | grep -q device; then adb reboot bootloader; sleep 8; fi
cat <<EOF
The phone boots HakiOS; when the lock screen is up (about 4 minutes):
  - swipe up; Settings > Wi-Fi to join a network (every boot: this Beta does not keep /private/var on the phone)
  - from this Mac, on the same network:  ssh -i $K/ssh/client_ed25519 root@<the phone's address>
    (Settings > Wi-Fi > (i) shows the address; if the Mac cannot reach it, put both on an iPhone's hotspot)
The log: $WORK/out/logs/$NAME.txt
EOF
cd "$WORK"
# /private/var is NOT kept on the phone in this Beta (var_store=0 ufs_write=0): keeping it needs a partition "darwin" cut
# from userdata, which this kit does not make. Each run starts from the data volume setup.sh built; within a run, a
# network once joined is joined again by itself (after a drop, or Wi-Fi off and on).
SECS=${SECS:-900} NAME=$NAME USBIMG=$WORK/out/hakios-fajita-usb.img hakios-fajita/scripts/run-darwin-live.sh "" "" \
	" var_store=0 ufs_write=0${EXTRA:+ $EXTRA}"
