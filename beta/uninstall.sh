#!/bin/bash
# HakiOS on the OnePlus 6T, Beta 0.4: off the phone again, from the backup install.sh kept (~/HakiOS-6T-backup/<serial>/).
#
#   ./uninstall.sh                   HakiOS's slot gets back its boot, dtbo and vbmeta as they were; Android's slot is
#                                    made active; the partition table is put back as it was (darwin gone, userdata
#                                    whole again); and userdata is made again (fastboot -w): Android starts as new.
#                                    EVERYTHING IN darwin (HakiOS's /private/var) AND IN ANDROID'S DATA IS ERASED.
#   KEEP_ANDROID_DATA=1 ./uninstall.sh   no fastboot -w: Android keeps what it has. The space darwin had comes back
#                                    only if Android grows its filesystem into it at its next start (it did on the
#                                    developer's phone; not promised): otherwise run fastboot -w later
#   KEEP_DARWIN=1 ./uninstall.sh     the partition table left as it is (darwin stays; ./install.sh puts HakiOS back
#                                    without erasing anything)
#   STOCK_BOOT=boot.img ./uninstall.sh   the boot image to put back into HakiOS's slot, when the one saved before the
#                                    install was HakiOS's own (the backup's info.txt says so)
#   REMOVE=yes                       answers the question before anything is changed
set -e
ME=uninstall
. "$(cd "$(dirname "$0")" && pwd)/lib-install.sh"
command -v fastboot >/dev/null || die "no fastboot (brew install android-platform-tools)"
[ "$(fastboot devices | wc -l)" -le 1 ] || die "more than one phone in fastboot: leave one"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

to_abl
SERIAL=$(fastboot devices | awk '$2=="fastboot" && $1!="xnuloader" {print $1; exit}')
BK=$BACKUPS/$SERIAL
[ -f "$BK/info.txt" ] || die "no backup of this phone ($BK): it was not installed from this Mac"
(cd "$BK" && shasum -a 256 -c SHA256SUMS >/dev/null) || die "the backup in $BK does not check (SHA256SUMS)"
mkdir -p "$BK/logs"
LOG=$BK/logs/uninstall-$(date +%Y%m%d-%H%M%S).txt
TARGET=$(sed -n 's/.* target=\([ab]\).*/\1/p' "$BK/info.txt")
ANDROID=$(other_slot "$TARGET")
BOOT=$BK/boot_$TARGET.img
if carries_hakios "$BOOT"; then
	[ -n "${STOCK_BOOT:-}" ] && [ -f "$STOCK_BOOT" ] ||
		die "the boot_$TARGET saved before the install was HakiOS's own: give the phone's own as STOCK_BOOT=boot.img"
	carries_hakios "$STOCK_BOOT" && die "$STOCK_BOOT is HakiOS's boot image, not the phone's own"
	BOOT=$STOCK_BOOT
fi
cat <<EOF

    HakiOS comes off this phone ($SERIAL), from $BK:
      - slot $TARGET: boot, dtbo and vbmeta as they were$( [ "$BOOT" = "${STOCK_BOOT:-}" ] && echo " (boot: $STOCK_BOOT)")
      - slot $ANDROID (Android) made active
$( [ -z "${KEEP_DARWIN:-}" ] && echo "      - the partition table as it was: darwin and all HakiOS keeps in it (its /private/var) ERASED")
$( [ -z "${KEEP_DARWIN:-}" ] && [ -z "${KEEP_ANDROID_DATA:-}" ] && echo "      - userdata made again (fastboot -w): ANDROID'S DATA ERASED, Android starts as new")

EOF
if [ "${REMOVE:-}" = yes ]; then answer=REMOVE; else read -r -p "    Type REMOVE to go on: " answer; fi
[ "$answer" = REMOVE ] || die "nothing was changed"

# --- the partition table ----------------------------------------------------------------------------------------------
if [ -z "${KEEP_DARWIN:-}" ]; then
	to_loader
	read_gpt "$T"
	table_of "$T"
	[ "$COPIES" = same ] || mend_gpt "$T"
	if [ "$DW" = none ] && [ -f "$BK/unwipe-pending" ]; then
		# the last run put the table back and stopped before userdata was made again
		to_abl
		say "making userdata again (fastboot -w), as the last run did not"
		fb -w >/dev/null || { echo "$FB_OUT" >&2; die "fastboot -w failed: run ./uninstall.sh again"; }
		printf '%s\n' "$FB_OUT" | grep -q "Writing 'userdata'" || { echo "$FB_OUT" >&2; die "fastboot -w did not format userdata"; }
		rm -f "$BK/unwipe-pending"
	elif [ "$DW" = none ]; then
		say "the partition table has no darwin: left as it is"
	else
		python3 "$GPTPLAN" restore "$T/head.bin" "$T/tail.bin" "$BK/gpt-head.bin" "$BK/gpt-tail.bin" "$T/restore.stg" |
			tee -a "$LOG" > "$T/plan.txt"
		grep -q '^TABLE ' "$T/plan.txt" || die "the saved table cannot be put back: $(grep REFUSE "$T/plan.txt")"
		UD_LAST=$(sed -n 's/^TABLE userdata=[0-9]*\.\.\([0-9]*\).*/\1/p' "$T/plan.txt")
		say "putting back the partition table from before the install"
		[ -n "${KEEP_ANDROID_DATA:-}" ] || : > "$BK/unwipe-pending"
		fbq oem ramdisk >/dev/null || die "the loader would not take the table ($FB_OUT)"
		fb stage "$T/restore.stg" >/dev/null || die "sending the table failed"
		fbq oem gptcheck >/dev/null || die "the loader refuses the table: $FB_OUT"
		rc=0; fb oem gptwrite >/dev/null || rc=$?; GW_OUT=$FB_OUT
		loader_log "$T/gptwrite.log" || true
		cat "$T/gptwrite.log" >> "$LOG" 2>/dev/null || true
		[ $rc -eq 0 ] && printf '%s\n' "$GW_OUT" | grep -q "written" ||
			die "the table was not written whole: run ./uninstall.sh again (it mends the two copies)"
		read_twice "$T/head.new" oem readunit "$UNIT" 0 8
		cmp -s <(dd if="$T/head.new" bs=4096 skip=1 count=1 2>/dev/null) <(dd if="$T/restore.stg" bs=4096 count=1 2>/dev/null) ||
			die "the primary header read back is not the one sent"
		to_abl
		want=$(( (UD_LAST - UD_FIRST + 1) * 4096 ))
		have=$(getvar partition-size:userdata)
		[ -n "$have" ] && [ $((have)) -eq $want ] || die "ABL gives userdata $have bytes, not $want: it has not taken the table"
		say "the table is the phone's own again: userdata $((want / 1073741824)) GiB"
		if [ -z "${KEEP_ANDROID_DATA:-}" ]; then
			say "making userdata again (fastboot -w)"
			fb -w >/dev/null || { echo "$FB_OUT" >&2; die "fastboot -w failed"; }
			printf '%s\n' "$FB_OUT" | grep -q "Writing 'userdata'" || { echo "$FB_OUT" >&2; die "fastboot -w did not format userdata"; }
			rm -f "$BK/unwipe-pending"
		fi
	fi
fi

# --- the slot ---------------------------------------------------------------------------------------------------------
to_abl
fb flash "boot_$TARGET" "$BOOT" >/dev/null || die "flashing boot_$TARGET failed"
fb flash "dtbo_$TARGET" "$BK/dtbo_$TARGET.img" >/dev/null || die "flashing dtbo_$TARGET failed"
fb flash "vbmeta_$TARGET" "$BK/vbmeta_$TARGET.img" >/dev/null || die "flashing vbmeta_$TARGET failed"
fb set_active "$ANDROID" >/dev/null || die "fastboot set_active $ANDROID failed"
[ "$(getvar current-slot)" = "$ANDROID" ] || die "ABL did not make slot $ANDROID active"
say "slot $TARGET as it was; slot $ANDROID active"
fbq reboot >/dev/null || true
echo "$ME: done: the phone starts Android. The backup stays in $BK; the log of this run: $LOG"
