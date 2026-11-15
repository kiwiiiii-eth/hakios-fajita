#!/bin/bash
# HakiOS on the OnePlus 6T, Beta 0.4: make everything a run or an install needs, from this kit, your own IPSW and your own phone.
#
#   ./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw
#
# What it does (each step is skipped when its result is already there; run it again after a failure):
#   1. checks the tools: macOS (Apple silicon or Intel), python3, fastboot, adb, 7zz, zstd, cc, curl, 15 GB free
#   2. fetches the sources of this release from GitHub (hakios-xnu-kernel at fajita-v0.4-beta, hakios-fajita at v0.4-beta)
#   3. puts the kit's prebuilt kernel and programs in place (nothing is compiled)
#   4. pulls the phone's firmware over adb (the phone in Android, USB debugging on): hakios-fajita/pull-firmware.sh
#   5. unpacks your IPSW (sysimage/unpack.sh, about 5 minutes)
#   6. fills the kit's blank loader with the identity from your IPSW's device tree, and packs the USB boot image
#   7. makes your SSH keys (work/hakios-xnu-kernel/ssh/, never shared) and fetches the package manager's prefix
#   8. builds root.apfs and system.apfs (about 5 minutes)
# Then ./run.sh boots it from the Mac (nothing flashed: the phone keeps Android, a reboot goes back to it), or
# ./install.sh puts it on the phone, which then starts iOS by itself (see README.md: it erases Android's data).
#
# No Apple software and no vendor firmware are in this kit: the system image is made here from your IPSW, the firmware
# is taken from your phone, and the loader carries no identity until step 6 writes yours into it.
set -e
KIT=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-$KIT/work}
IPSW=${1:-${IPSW:-}}
XNU_TAG=fajita-v0.4-beta
DEV_TAG=v0.4-beta
GH=https://github.com/kiwiiiii-eth
K=$WORK/hakios-xnu-kernel
D=$WORK/hakios-fajita

say() { printf '\n== %s\n' "$*"; }
die() { printf '\nsetup.sh: %s\n' "$*" >&2; exit 1; }

# --- 1. tools ---------------------------------------------------------------------------------------
say "1/8 checking the tools"
[ "$(uname -s)" = Darwin ] || die "this kit is for a Mac (macOS); on Linux, build from source (hakios-fajita's README)"
missing=
for t in python3 fastboot adb 7zz zstd cc curl shasum timeout; do command -v $t >/dev/null || missing="$missing $t"; done
[ -z "$missing" ] || die "missing:$missing
  Install Homebrew (https://brew.sh; it installs Apple's Command Line Tools, which have cc), then:
    brew install python sevenzip zstd coreutils android-platform-tools"
python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' || die "python3 is $(python3 -V 2>&1): 3.10 or newer is needed (brew install python)"
free_gb=$(df -g "$KIT" | awk 'NR==2 {print $4}')
[ "${free_gb:-0}" -ge 15 ] || die "only ${free_gb} GB free where the kit is: 15 GB are needed"
[ -n "$IPSW" ] || die "give your IPSW: ./setup.sh ~/Downloads/iPhone10,3,iPhone10,6_16.5_20F66_Restore.ipsw
  (Apple's iOS 16.5 for iPhone X, 20F66, 6165698198 bytes; e.g. from https://ipsw.me/iPhone10,3)"
[ -f "$IPSW" ] || die "$IPSW: no such file"
(cd "$KIT" && shasum -a 256 -c SHA256SUMS >/dev/null) || die "the kit's files do not match SHA256SUMS: download it again"
echo "ok"

# --- 2. sources -------------------------------------------------------------------------------------
say "2/8 the sources of $DEV_TAG"
mkdir -p "$WORK"
# (LOCAL_SRC=DIR: the two repositories' committed HEADs from checkouts in DIR instead -- the kit tried before its release)
fetch_src() { # REPO TAG DIR
	[ -f "$3/.hakios-tag" ] && [ "$(cat "$3/.hakios-tag")" = "$2" ] && return 0
	rm -rf "$3" "$3.part"; mkdir -p "$3.part"
	if [ -n "${LOCAL_SRC:-}" ]; then
		(cd "$LOCAL_SRC/$1" && git archive HEAD) | tar -x -C "$3.part" || die "could not take $1 from $LOCAL_SRC"
	else
		curl -fsSL "$GH/$1/archive/refs/tags/$2.tar.gz" | tar -xz -C "$3.part" --strip-components 1 || die "could not fetch $1 at $2"
	fi
	echo "$2" > "$3.part/.hakios-tag"; mv "$3.part" "$3"
	echo "$1 at $2"
}
fetch_src hakios-xnu-kernel $XNU_TAG "$K"
fetch_src hakios-fajita $DEV_TAG "$D"
[ -e "$K/devices/fajita" ] || ln -s ../../hakios-fajita "$K/devices/fajita"
export PATH="$D/hostbin:$PATH"          # 7z (7zz), sha256sum, ... as the scripts call them
(cd "$K" && python3 tools/hakios-config.py defconfig fajita >/dev/null) || die "the configuration could not be made"

# --- 3. prebuilt ------------------------------------------------------------------------------------
say "3/8 the prebuilt kernel and programs"
cp "$KIT/prebuilt/hakios-kernel" "$K/hakios-kernel"
rm -rf "$K/prebuilt/userland"; mkdir -p "$K/prebuilt/userland"
cp "$KIT"/prebuilt/userland/* "$K/prebuilt/userland/"
want=$(cd "$K" && python3 tools/hakios-config.py builtin --sha)
have=$(cat "$KIT/prebuilt/hakios-kernel.args-sha")
[ "$want" = "$have" ] || die "the kernel was built for another configuration ($have, the sources say $want)"
echo "ok"

# --- 4. firmware ------------------------------------------------------------------------------------
say "4/8 the phone's firmware"
# (FW=DIR: take fw-gpu, fw-modem and fw-bt from DIR, e.g. an earlier kit's work/hakios-xnu-kernel, instead of the phone)
if [ -n "${FW:-}" ] && [ ! -f "$K/fw-modem/modem.mdt" ]; then
	for d in fw-gpu fw-modem fw-bt; do [ -d "$FW/$d" ] && cp -R "$FW/$d" "$K/"; done
fi
if [ -f "$K/fw-modem/modem.mdt" ] && [ -f "$K/fw-gpu/a630_zap.mdt" ] && [ -f "$K/fw-bt/crbtfw21.tlv" ] &&
   [ -f "$K/fw-gpu/a630_gmu.bin" ] && [ -f "$K/fw-modem/ath10k/WCN3990/hw1.0/board-2.bin" ]; then
	echo "already there (delete work/hakios-xnu-kernel/fw-* to pull again)"
else
	echo "Boot the 6T into Android, turn on Settings > System > Developer options > USB debugging, connect it, and allow"
	echo "this computer on the phone. Waiting for it on adb ..."
	adb wait-for-device
	K=$K "$D/pull-firmware.sh"
fi

# --- 5. the IPSW ------------------------------------------------------------------------------------
say "5/8 unpacking your IPSW (about 5 minutes the first time)"
(cd "$K" && sysimage/unpack.sh "$IPSW")

# --- 6. the loader and the USB boot image -----------------------------------------------------------
say "6/8 the loader, with your IPSW's identity, and the USB boot image"
cp "$KIT/prebuilt/loader.blank.efi" "$K/xnuloader/loader.efi"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 "$K/xnuloader/im4p.py" "$K/sysimage/DeviceTree.d22ap.im4p" "$T/dt.lzfse" >/dev/null
/usr/bin/compression_tool -decode -a lzfse -i "$T/dt.lzfse" -o "$T/dt.bin"
python3 "$K/xnuloader/mkidentity.py" --fill "$K/xnuloader/loader.efi" "$T/dt.bin"
HAKIOS_ROOT=$WORK "$D/scripts/mk-usbimg.sh" >/dev/null
[ -f "$WORK/out/hakios-fajita-usb.img" ] || die "the USB boot image was not made"
echo "ok: work/out/hakios-fajita-usb.img"

# --- 7. SSH keys and the package manager's prefix ---------------------------------------------------
say "7/8 your SSH keys and the package manager's prefix (sshd, zsh, neofetch)"
mkdir -p "$K/ssh"
[ -f "$K/ssh/ssh_host_ed25519_key" ] || ssh-keygen -q -t ed25519 -N '' -C hakios-6t-host -f "$K/ssh/ssh_host_ed25519_key"
[ -f "$K/ssh/client_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C hakios-6t-login -f "$K/ssh/client_ed25519"
cp "$K/ssh/client_ed25519.pub" "$K/ssh/authorized_keys"
[ -d "$K/jb/root/var/jb" ] || (cd "$K" && tools/mk-jb.sh)

# --- 8. the images ----------------------------------------------------------------------------------
say "8/8 root.apfs and system.apfs (about 5 minutes)"
(cd "$K" && PREBUILT=1 ALLOW=locationd BT=1 GL=1 REST=1 MODEM=1 SYSTEM=1 RC=rc.launchd.aks RC_JOBS=rc.jobs.ssh6t QUIET=1 userland/build.sh | tail -3)
[ -f "$K/userland/system.apfs" ] && [ -f "$K/userland/root.apfs" ] || die "the images were not made"

say "done. Put the phone in fastboot (or leave it in Android) and run: ./run.sh (from the Mac) or ./install.sh (onto the phone)"
