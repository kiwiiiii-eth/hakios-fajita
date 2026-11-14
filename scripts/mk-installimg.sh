#!/bin/bash
# The boot image of a phone that boots HakiOS by itself, with no host (Beta 0.4): U-Boot and the loader, and in the
# loader's payload the kernel, the small root (root.apfs, md1) and rdsrc=darwin -- the system image (md0) is not in it
# (2.5 GB: the boot partition has 64 MB) but read at boot from the partition darwin, where `fastboot oem darwinput`
# wrote it (xnuloader/loader.c, "The system image in darwin"). This script only builds the file; it flashes nothing.
#
#   mk-installimg.sh            → $ROOT/out/hakios-fajita-install.img: runs until iOS shuts down or restarts, which power
#                                 the phone off or reset it into its boot slot again (halt_psci=1, PSCI)
#   SECS=600 mk-installimg.sh   → $ROOT/out/hakios-fajita-oneshot.img: a test from a host (`fastboot boot` it): the run
#                                 ends after SECS as a run from the Mac does, and the loader goes back to U-Boot
#
# The kernel's clock: the host's time when this image is built (epoch=); iOS sets it right from the network.
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}; K=$ROOT/hakios-xnu-kernel
UB=${UB:-$REPO/prebuilt/u-boot.bin}
KERNEL=${KERNEL:-$K/hakios-kernel}
RD=${RD:-$K/userland/root.apfs}
. "$REPO/scripts/lib-args.sh"
resolve_args "$K" "$KERNEL" || exit 1
[ -f "$K/xnuloader/loader.efi" ] || { echo "mk-installimg.sh: no loader: build xnuloader first" >&2; exit 1; }
strings -a "$K/xnuloader/loader.efi" | grep -q "rdsrc=darwin" ||
	{ echo "mk-installimg.sh: this loader cannot read the system image from darwin (rdsrc): rebuild xnuloader" >&2; exit 1; }
if [ -n "${SECS:-}" ]; then
	END="loader_return_after=$SECS"; OUTNAME=hakios-fajita-oneshot.img
else
	END="halt_psci=1"; OUTNAME=hakios-fajita-install.img
fi
CMDLINE="$END epoch=$(date +%s) sb_delay=8 ${PRE:-} $ARGS $SOCARGS${EXTRA:+ $EXTRA}"
echo "mk-installimg.sh: cmdline=$CMDLINE"
mkdir -p "$K/build" "$ROOT/out"
cd "$K"
python3 xnuloader/mkpayload.py -o build/install-payload.bin loader.efi=xnuloader/loader.efi kernel="$KERNEL" ramdisk="$RD" \
	--cmdline "$CMDLINE" --rdsrc darwin >/dev/null
python3 tools/mkubootimg.py -d fajita -u "$UB" -p build/install-payload.bin -c build/install.hkub >/dev/null
"$REPO/scripts/pack-fajita.sh" "$UB" build/install.hkub >/dev/null
mv "$ROOT/out/hakios-u-boot-fajita.img" "$ROOT/out/$OUTNAME"
size=$(stat -f %z "$ROOT/out/$OUTNAME")
[ "$size" -le $((64 * 1048576)) ] || { echo "mk-installimg.sh: $OUTNAME is $size bytes: more than the 64 MB boot partition" >&2; exit 1; }
ls -la "$ROOT/out/$OUTNAME"
