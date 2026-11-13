#!/bin/bash
# Pull the OnePlus 6T's own firmware out of its Android into the fw-*/ directories of hakios-xnu-kernel (never committed:
# it is Qualcomm's and OnePlus's), and fetch the open part from linux-firmware. `make firmware` runs this
# (devices/fajita/pull-firmware.sh). The phone is in Android with USB debugging on and this computer allowed.
#
#   fw-gpu/    a630_zap.mdt + a630_zap.b* (the phone's, signed for its TrustZone); a630_gmu.bin, a630_sqe.fw (linux-firmware)
#   fw-modem/  modem.mdt + modem.b*, mba.mbn, and image/ whole: the modem's, the audio DSP's (adsp.*) and Wi-Fi's board
#              files (bdwlan.*, wlanmdsp.mbn), which the modem reads over TFTP; into image/ too the IPA's firmware
#              (ipa_fws.mdt + .b*, which Android keeps in /vendor/firmware: LTE data); ath10k/WCN3990/hw1.0/firmware-5.bin
#              and board-2.bin (linux-firmware)
#   fw-bt/     crbtfw21.tlv, crnv21.bin: the WCN3990's Bluetooth rampatch and NVM (the phone's bluetooth partition)
#
# A plain `adb pull` first; where the files are not readable by adb's shell user (some ROMs mount /vendor/firmware_mnt with
# fmask=0337), the same through `su` if the phone has root: copied to a world-readable staging directory in /data/local/tmp,
# pulled, and the staging directory removed. Nothing on the phone is changed.
#   NO_LINUX_FIRMWARE=1   do not fetch from linux-firmware (put those four files in place yourself)
set -e
HERE=$(cd -P "$(dirname "$0")" && pwd)
K=${K:-$(cd "$HERE/../.." 2>/dev/null && [ -f tools/hakios-config.py ] && pwd || echo "$(dirname "$HERE")/hakios-xnu-kernel")}
[ -f "$K/tools/hakios-config.py" ] || { echo "pull-firmware.sh: no hakios-xnu-kernel at $K (K=...)" >&2; exit 1; }
cd "$K"
LF=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain

command -v adb >/dev/null || { echo "pull-firmware.sh: adb is not installed (Android platform-tools)" >&2; exit 1; }
state=$(adb get-state 2>&1 || true)
[ "$state" = device ] || { echo "pull-firmware.sh: no phone on adb ($state): boot Android, turn USB debugging on, allow this computer" >&2; exit 1; }
model=$(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')
case "$model" in
	OnePlus6T|fajita|OnePlus6TSingle) ;;
	*) echo "pull-firmware.sh: the phone says it is \"$model\", not a OnePlus 6T (fajita): stopping" >&2; exit 1 ;;
esac
echo "pull-firmware.sh: OnePlus 6T, $(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"

# where Android keeps them (the Bluetooth partition is mounted at /vendor/bt_firmware on OxygenOS; /vendor/firmware elsewhere)
IMAGE=/vendor/firmware_mnt/image
ZAP="/vendor/firmware/a630_zap.*"
IPA="/vendor/firmware/ipa_fws.*"
BT_DIRS="/vendor/bt_firmware/image /bt_firmware/image /vendor/firmware"

STAGE=fw-stage.$$
rm -rf "$STAGE"; mkdir -p "$STAGE"
trap 'rm -rf "$STAGE"' EXIT

plain_pull() {
	mkdir -p "$STAGE/image" "$STAGE/gpu" "$STAGE/bt"
	adb pull "$IMAGE" "$STAGE/" >/dev/null 2>&1 || return 1
	[ -f "$STAGE/image/modem.mdt" ] && [ -f "$STAGE/image/adsp.mdt" ] || return 1
	for f in $(adb shell "ls $ZAP" 2>/dev/null | tr -d '\r'); do adb pull "$f" "$STAGE/gpu/" >/dev/null 2>&1 || return 1; done
	ls "$STAGE"/gpu/a630_zap.mdt >/dev/null 2>&1 || return 1
	mkdir -p "$STAGE/ipa"
	for f in $(adb shell "ls $IPA" 2>/dev/null | tr -d '\r'); do adb pull "$f" "$STAGE/ipa/" >/dev/null 2>&1 || return 1; done
	for d in $BT_DIRS; do
		adb pull "$d/crbtfw21.tlv" "$STAGE/bt/" >/dev/null 2>&1 && adb pull "$d/crnv21.bin" "$STAGE/bt/" >/dev/null 2>&1 && return 0
	done
	return 1
}

root_pull() {
	local S=/data/local/tmp/hakios-fw
	adb shell "su -c id" 2>/dev/null | grep -q "uid=0" || return 1
	echo "pull-firmware.sh: not readable as adb's shell user; copying through su (nothing on the phone is changed)"
	adb shell "su -c 'sh -c \"rm -rf $S; mkdir -p $S/gpu $S/bt $S/ipa; cp -r $IMAGE $S/; cp $ZAP $S/gpu/ 2>/dev/null; cp $IPA $S/ipa/ 2>/dev/null;
		for d in $BT_DIRS; do [ -f \\\$d/crbtfw21.tlv ] && cp \\\$d/crbtfw21.tlv \\\$d/crnv21.bin $S/bt/ && break; done;
		chmod -R a+rX $S\"'" >/dev/null
	rm -rf "$STAGE"; adb pull "$S" "$STAGE" >/dev/null
	adb shell "su -c 'rm -rf $S'" >/dev/null
	[ -f "$STAGE/image/modem.mdt" ] && [ -f "$STAGE/gpu/a630_zap.mdt" ] && [ -f "$STAGE/bt/crbtfw21.tlv" ]
}

if ! plain_pull; then
	root_pull || { echo "pull-firmware.sh: the firmware is not readable as adb's shell user, and the phone has no root that answers su -c: \
pull /vendor/firmware_mnt/image, /vendor/firmware/a630_zap.* and the Bluetooth partition's crbtfw21.tlv and crnv21.bin yourself" >&2; exit 1; }
fi

# into place: fw-modem/image whole, and the modem's own image files beside it (hakios.mpss845.c reads them from fw-modem/)
rm -rf fw-modem/image fw-bt
mkdir -p fw-modem fw-gpu fw-bt
mv "$STAGE/image" fw-modem/image
cp fw-modem/image/modem.mdt fw-modem/image/modem.b* fw-modem/image/mba.mbn fw-modem/
cp "$STAGE"/gpu/a630_zap.* fw-gpu/
if ls "$STAGE"/ipa/ipa_fws.mdt >/dev/null 2>&1; then
	cp "$STAGE"/ipa/ipa_fws.* fw-modem/image/
elif [ ! -f fw-modem/image/ipa_fws.mdt ]; then
	echo "pull-firmware.sh: no /vendor/firmware/ipa_fws.mdt on the phone: without it there is no LTE data (Wi-Fi and the rest work)" >&2
fi
cp "$STAGE"/bt/crbtfw21.tlv "$STAGE"/bt/crnv21.bin fw-bt/

if [ -z "${NO_LINUX_FIRMWARE:-}" ]; then
	fetch() { # PATH-IN-LINUX-FIRMWARE DEST
		[ -s "$2" ] && return 0
		mkdir -p "$(dirname "$2")"
		curl -fsSL "$LF/$1" -o "$2.part" && mv "$2.part" "$2" || { rm -f "$2.part"; echo "pull-firmware.sh: could not fetch $1" >&2; return 1; }
	}
	fetch qcom/a630_gmu.bin fw-gpu/a630_gmu.bin
	fetch qcom/a630_sqe.fw fw-gpu/a630_sqe.fw
	fetch ath10k/WCN3990/hw1.0/firmware-5.bin fw-modem/ath10k/WCN3990/hw1.0/firmware-5.bin
	fetch ath10k/WCN3990/hw1.0/board-2.bin fw-modem/ath10k/WCN3990/hw1.0/board-2.bin
fi

echo "pull-firmware.sh: fw-gpu $(ls fw-gpu | wc -l | tr -d ' ') files, fw-modem $(find fw-modem -type f | wc -l | tr -d ' '), fw-bt $(ls fw-bt | wc -l | tr -d ' ')"
# against the firmware this release was tested with (their hashes only, firmware.sha256): a difference may still work
if [ -f "$HERE/firmware.sha256" ]; then
	if shasum -a 256 -c "$HERE/firmware.sha256" >/dev/null 2>&1; then
		echo "pull-firmware.sh: the same firmware as the release was tested with"
	else
		echo "pull-firmware.sh: NOT the firmware this release was tested with ($(shasum -a 256 -c "$HERE/firmware.sha256" 2>/dev/null | grep -c FAILED) files differ): it may still work; say so in a report"
	fi
fi
