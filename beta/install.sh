#!/bin/bash
# HakiOS on the OnePlus 6T, Beta 0.4: installed, so that the phone starts iOS by itself -- no Mac, no cable.
#
#   ./install.sh                 install; run again to update an install (steps 3 and 4 only: nothing is erased)
#   GIB=32 ./install.sh          the size of the partition darwin when it is made (12 to 64; 32 by default)
#   TARGET=a|b ./install.sh      the slot to install into (by default the one HakiOS is in already, else the one
#                                Android is not using)
#
# What it does, saying each step before it; the ones that change the phone are marked *:
#   1.  the phone's partition table and boot, dtbo and vbmeta of both slots, read twice, are kept the first time in
#       ~/HakiOS-6T-backup/<serial>/ (never overwritten: uninstall.sh puts the phone back from it)
#   2*  if the phone has no partition darwin: one is made of the last GIB GiB of userdata. ANDROID'S DATA IS ERASED
#       (fastboot -w; Android starts as new). You type ERASE first; the loader writes the table only if it changes
#       nothing but userdata's end and darwin (xnuloader/gpt.c), and reads it back.
#   3*  the iOS system image (2.6 GB, built by ./setup.sh) is written into darwin and read back (about 3 minutes)
#   4*  HakiOS's boot image goes into the boot partition of its slot, that slot's dtbo and vbmeta become those of the
#       slot Android uses, and the slot is made active. Android stays whole in its own slot: ./switch.sh android
#
# Afterwards the phone starts iOS from its power button. /private/var (settings, Wi-Fi networks, what apps keep) is
# kept in darwin across restarts. Back to Android: ./switch.sh android; HakiOS off the phone: ./uninstall.sh.
#
# For re-testing a phone that had darwin: EXPECT_DARWIN=FIRST..LAST stops unless darwin is, or would be made,
# exactly those blocks; ERASE_ANDROID_DATA=yes answers step 2's question; NO_REBOOT=1 leaves the phone in fastboot.
set -e
ME=install
. "$(cd "$(dirname "$0")" && pwd)/lib-install.sh"
GIB=${GIB:-32}

# --- 0. what this needs ---------------------------------------------------------------------------------------------
[ -f "$K/userland/system.apfs" ] && [ -f "$K/userland/root.apfs" ] && [ -f "$USBIMG" ] && [ -f "$K/xnuloader/loader.efi" ] ||
	die "run ./setup.sh first"
LC_ALL=C grep -a -q "oem gptwrite" "$K/xnuloader/loader.efi" || die "this loader is older than Beta 0.4: run ./setup.sh again"
command -v fastboot >/dev/null || die "no fastboot (brew install android-platform-tools)"
[ "$GIB" -ge 12 ] && [ "$GIB" -le 64 ] 2>/dev/null || die "GIB is to be 12 to 64"
[ "$(fastboot devices | wc -l)" -le 1 ] || die "more than one phone in fastboot: leave one"
if [ ! -d "$K/.git" ]; then export HAKIOS_VERSION_SUFFIX=${HAKIOS_VERSION_SUFFIX:--v0.4-beta}; fi
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

to_abl
SERIAL=$(fastboot devices | awk '$2=="fastboot" && $1!="xnuloader" {print $1; exit}')
[ -n "$SERIAL" ] || die "no serial number from ABL"
BK=$BACKUPS/$SERIAL
mkdir -p "$BK/logs"
LOG=$BK/logs/install-$(date +%Y%m%d-%H%M%S).txt
say "the phone: $SERIAL; this run's log: $LOG"
[ "$(getvar unlocked)" = yes ] || die "the boot loader is locked (fastboot flashing unlock first, which erases the phone)"
CUR=$(getvar current-slot)
case "$CUR" in a|b) ;; *) die "ABL gives no current slot ($CUR)" ;; esac

# --- 1. what the phone has, read twice; the backup, the first time --------------------------------------------------
to_loader
say "1. reading the partition table and boot, dtbo and vbmeta of both slots"
read_gpt "$T"
for p in boot_a boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b; do read_part "$T" $p; done
HAKIOS_IN=
for s in a b; do carries_hakios "$T/boot_$s.img" && HAKIOS_IN="$HAKIOS_IN$s"; done
if [ -n "${TARGET:-}" ]; then
	case "$TARGET" in a|b) ;; *) die "TARGET is a or b" ;; esac
elif [ -f "$BK/info.txt" ]; then
	# installed before from this Mac: the slot it went into, whatever its boot partition holds now
	TARGET=$(sed -n 's/.* target=\([ab]\).*/\1/p' "$BK/info.txt")
	[ -n "$TARGET" ] || die "$BK/info.txt names no slot"
elif [ ${#HAKIOS_IN} -eq 1 ]; then TARGET=$HAKIOS_IN
elif [ "$HAKIOS_IN" = ab ]; then TARGET=$CUR
else TARGET=$(other_slot "$CUR"); fi
ANDROID=$(other_slot "$TARGET")
say "   HakiOS goes into slot $TARGET; slot $ANDROID is left as it is (current slot: $CUR; HakiOS in: ${HAKIOS_IN:-none})"
if [ ! -f "$BK/info.txt" ]; then
	cp "$T/head.bin" "$BK/gpt-head.bin"; cp "$T/tail.bin" "$BK/gpt-tail.bin"
	for p in boot_a boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b; do cp "$T/$p.img" "$BK/$p.img"; done
	{
		echo "saved $(date '+%Y-%m-%d %H:%M:%S') by install.sh, before HakiOS was installed on this phone"
		echo "serial=$SERIAL unit=$UNIT blocks=$BLOCKS current_slot=$CUR target=$TARGET android=$ANDROID"
		for s in a b; do carries_hakios "$BK/boot_$s.img" && echo "boot_$s=hakios (NOT the phone's own: uninstall.sh needs STOCK_BOOT)"; done
		true
	} > "$BK/info.txt"
	(cd "$BK" && shasum -a 256 gpt-head.bin gpt-tail.bin boot_?.img dtbo_?.img vbmeta_?.img > SHA256SUMS)
	say "   kept in $BK (keep this folder: uninstall.sh puts the phone back from it)"
else
	(cd "$BK" && shasum -a 256 -c SHA256SUMS >/dev/null) || die "the backup in $BK does not check (SHA256SUMS)"
	say "   the backup from the first install is in $BK, and checks"
fi
table_of "$T"
[ -z "${EXPECT_DARWIN:-}" ] || [ "$DW" = none ] || [ "$DW" = "$EXPECT_DARWIN" ] ||
	die "darwin is $DW, not $EXPECT_DARWIN: stopped"

# --- 2. the partition darwin ----------------------------------------------------------------------------------------
if [ "$DW" = none ]; then
	python3 "$GPTPLAN" carve "$T/head.bin" "$T/tail.bin" "$GIB" "$T/carve.stg" | tee -a "$LOG" > "$T/plan.txt" ||
		die "no partition table can be made for darwin: $(grep REFUSE "$T/plan.txt")"
	grep -q '^TABLE ' "$T/plan.txt" || die "no partition table can be made for darwin: $(grep REFUSE "$T/plan.txt")"
	NEW_DW=$(sed -n 's/^TABLE .* darwin=\([^ ]*\).*/\1/p' "$T/plan.txt")
	NEW_UD_LAST=$(sed -n 's/^TABLE userdata=[0-9]*\.\.\([0-9]*\).*/\1/p' "$T/plan.txt")
	[ -z "${EXPECT_DARWIN:-}" ] || [ "$NEW_DW" = "$EXPECT_DARWIN" ] || die "darwin would be $NEW_DW, not $EXPECT_DARWIN: stopped"
	echo
	sed -n '1,3p' "$T/plan.txt" | sed 's/^/    /'
	cat <<EOF

    2. The partition darwin is made of the last $GIB GiB of userdata.
       EVERYTHING ANDROID KEEPS ON THIS PHONE IS ERASED: apps, photos, accounts, files. Android starts as new.
       (Its table as it is now is saved in $BK; ./uninstall.sh puts it back.)

EOF
	if [ "${ERASE_ANDROID_DATA:-}" = yes ]; then answer=ERASE; else read -r -p "    Type ERASE to go on: " answer; fi
	[ "$answer" = ERASE ] || die "nothing was changed"
	say "2. writing the new partition table"
	fbq oem ramdisk >/dev/null || die "the loader would not take the table ($FB_OUT)"
	fb stage "$T/carve.stg" >/dev/null || die "sending the table failed"
	fbq oem gptcheck >/dev/null || die "the loader refuses the table: $FB_OUT"
	rc=0; fb oem gptwrite >/dev/null || rc=$?; GW_OUT=$FB_OUT
	loader_log "$T/gptwrite.log" || true
	cat "$T/gptwrite.log" >> "$LOG" 2>/dev/null || true
	[ $rc -eq 0 ] && printf '%s\n' "$GW_OUT" | grep -q "written" || {
		echo "$GW_OUT" >&2
		die "the table was not written whole. Do not restart into Android. The table from before is in $BK (gpt-head.bin,
gpt-tail.bin): run ./install.sh again (it mends the two copies) or ./uninstall.sh"; }
	read_twice "$T/head.new" oem readunit "$UNIT" 0 8
	cmp -s <(dd if="$T/head.new" bs=4096 skip=1 count=1 2>/dev/null) <(dd if="$T/carve.stg" bs=4096 count=1 2>/dev/null) ||
		die "the primary header read back is not the one sent"
	say "   written and read back: userdata ends at $NEW_UD_LAST, darwin $NEW_DW"
	# ABL reads the table when it starts: only then does it know userdata's new size
	to_abl
	want=$(( (NEW_UD_LAST - UD_FIRST + 1) * 4096 ))
	have=$(getvar partition-size:userdata)
	[ -n "$have" ] && [ $((have)) -eq $want ] ||
		die "ABL gives userdata $have bytes, not $want: it has not taken the new table; nothing erased"
	ptype=$(getvar partition-type:userdata)
	case "$ptype" in f2fs|ext4) ;; *) die "ABL gives userdata the type '$ptype': fastboot -w could not format it" ;; esac
	say "   ABL sees userdata of $((want / 1073741824)) GiB ($ptype): erasing and formatting it (fastboot -w)"
	fb -w >/dev/null || { echo "$FB_OUT" >&2; die "fastboot -w failed: userdata is not usable by Android until it is made again"; }
	printf '%s\n' "$FB_OUT" | grep -q "Writing 'userdata'" ||
		{ echo "$FB_OUT" >&2; die "fastboot -w did not format userdata"; }
	say "   userdata made again"
	to_loader
	fbq oem darwininfo >/dev/null || die "the loader does not see darwin after the restart ($FB_OUT)"
	DW=$NEW_DW
else
	first=${DW%..*}; last=${DW#*..}
	[ $(( (last - first + 1) * 4096 )) -ge $((12 * 1073741824)) ] || die "the phone's darwin ($DW) is smaller than 12 GiB"
	say "2. darwin is there already ($DW): nothing erased"
fi

# --- 3. the system image ----------------------------------------------------------------------------------------------
to_loader
say "3. sending the system image (2.6 GB, about a minute) and writing it into darwin (about two)"
fbq oem ramdisk >/dev/null || die "the loader would not take the system image ($FB_OUT)"
fb stage "$K/userland/system.apfs" >/dev/null || die "sending the system image failed"
rc=0; fb oem darwinput "$(date +%s)" >/dev/null || rc=$?
loader_log "$T/darwinput.log" || true
cat "$T/darwinput.log" >> "$LOG" 2>/dev/null || true
[ $rc -eq 0 ] && LC_ALL=C grep -a -q "written and read back" "$T/darwinput.log" ||
	die "the system image was not written whole into darwin: run ./install.sh again"
say "   written and read back"

# --- 4. the boot image, and the slot ----------------------------------------------------------------------------------
say "4. the boot image"
HAKIOS_ROOT=$WORK "$D/scripts/mk-installimg.sh" >> "$LOG" 2>&1 || die "the boot image was not made (see the log)"
IMG=$WORK/out/hakios-fajita-install.img
to_abl
for p in dtbo vbmeta; do
	if ! cmp -s "$T/${p}_$TARGET.img" "$T/${p}_$ANDROID.img"; then
		say "   ${p}_$TARGET differs from slot $ANDROID's: flashing slot $ANDROID's"
		fb flash "${p}_$TARGET" "$T/${p}_$ANDROID.img" >/dev/null || die "flashing ${p}_$TARGET failed"
	fi
done
fb flash "boot_$TARGET" "$IMG" >/dev/null || die "flashing boot_$TARGET failed"
# read back through the loader, before the slot is made active
to_loader
read_part "$T" "boot_$TARGET"
same_prefix "$IMG" "$T/boot_$TARGET.img" || die "boot_$TARGET read back is not the image flashed"
to_abl
fb set_active "$TARGET" >/dev/null || die "fastboot set_active $TARGET failed"
[ "$(getvar current-slot)" = "$TARGET" ] || die "ABL did not make slot $TARGET active"
say "   boot_$TARGET flashed and read back; slot $TARGET active"
if [ -n "${NO_REBOOT:-}" ]; then say "done; the phone stays in fastboot (NO_REBOOT): fastboot reboot starts HakiOS"; exit 0; fi
fbq reboot >/dev/null || true
cat <<EOF

$ME: done. The phone starts HakiOS now (the screen stays dark for about 20 seconds, then iOS; the first start takes a
few minutes). From now on it starts iOS by itself from the power button.
  ./switch.sh android    back to Android (slot $ANDROID); ./switch.sh hakios to come back
  ./uninstall.sh         HakiOS off the phone, the phone as it was ($BK)
  the log of this run:   $LOG
EOF
