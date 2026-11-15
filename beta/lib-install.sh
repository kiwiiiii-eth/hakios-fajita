# Sourced by install.sh, uninstall.sh and switch.sh (Beta 0.4): finding the phone, moving it between ABL's fastboot
# and the HakiOS loader, reading its partitions twice, and the backup of how it was before HakiOS was installed.
#
# Rules kept by every function here: one fastboot command at a time, and no time limit on a command that moves data
# (stage, get_staged, flash) or writes (oem gptwrite, oem darwinput): a transfer cut short leaves the loader's USB
# stuck until the phone is restarted by hand.

KIT=${KIT:-$(cd "$(dirname "$0")" && pwd)}
WORK=${WORK:-$KIT/work}
K=$WORK/hakios-xnu-kernel
D=$WORK/hakios-fajita
USBIMG=${USBIMG:-$WORK/out/hakios-fajita-usb.img}
BACKUPS=${BACKUPS:-$HOME/HakiOS-6T-backup}
GPTPLAN=$K/tools/gpt-plan.py
export PATH="$D/hostbin:$PATH"
# HakiOS's boot image, as it lies in a boot partition: U-Boot is gzipped in it (pack-fajita.sh), but the container of
# the loader's payload (HKUB, tools/mkubootimg.py) and the payload (XNUP, xnuloader/mkpayload.py) are not

say() { echo "$ME: $*"; [ -n "${LOG:-}" ] && echo "$(date +%T) $*" >> "$LOG"; return 0; }
die() { echo "$ME: $*" >&2; [ -n "${LOG:-}" ] && echo "$(date +%T) STOPPED: $*" >> "$LOG"; exit 1; }

# a fastboot command, its output kept in the log; its exit status
fb() { local out rc=0; out=$(fastboot "$@" 2>&1) || rc=$?; [ -n "${LOG:-}" ] && printf '%s\n' "$ fastboot $*" "$out" >> "$LOG"; FB_OUT=$out; return $rc; }
# a short question (getvar, oem without a write): bounded, so that a phone gone away does not hang the script
fbq() { local out rc=0; out=$(timeout 15 fastboot "$@" 2>&1) || rc=$?; [ -n "${LOG:-}" ] && printf '%s\n' "$ fastboot $*" "$out" >> "$LOG"; FB_OUT=$out; return $rc; }
getvar() { fbq getvar "$1" >/dev/null 2>&1 || true; printf '%s\n' "$FB_OUT" | awk -v k="$1:" '$1==k {print $2; exit}'; }

state() {
	fastboot devices 2>/dev/null | awk '$1=="xnuloader" {print "loader"; exit} $1 ~ /^\?+$/ {print "uboot"; exit}
		$2=="fastboot" {print "abl"; exit}'
}
wait_for() { local want=$1 n=${2:-120}; for _ in $(seq 1 "$n"); do [ "$(state)" = "$want" ] && return 0; sleep 1; done; return 1; }

# the phone in ABL's fastboot, whatever it is in now
to_abl() {
	case "$(state)" in
	abl) return 0 ;;
	loader) fbq reboot >/dev/null || true ;;
	uboot) fbq oem run:"pmic dev pmic@0" >/dev/null && fbq oem run:"pmic write 0x88f 0x04" >/dev/null &&
		{ fbq oem run:reset >/dev/null || true; } ;;
	*) if command -v adb >/dev/null && adb get-state 2>/dev/null | grep -q device; then
		say "the phone is in Android: into its boot loader"; adb reboot bootloader
	   else
		say "waiting for the phone in fastboot: hold Power + Volume Up until the fastboot screen"
	   fi ;;
	esac
	wait_for abl 600 || die "no phone in ABL's fastboot"
	sleep 2
}

# the HakiOS loader, from ABL (the USB image: nothing of it is written to the phone)
to_loader() {
	[ "$(state)" = loader ] && return 0
	to_abl
	fb boot "$USBIMG" >/dev/null || die "fastboot boot of the loader failed"
	say "the loader starts (macOS takes about a minute to see its USB)"
	wait_for loader 300 || die "the loader's USB did not come up"
	fbq getvar version >/dev/null || sleep 5
}

# the loader's log of its last command, into $1
loader_log() { fbq oem log >/dev/null && fb get_staged "$1" >/dev/null; }

# what the loader staged (after oem readunit / oem readpart) into $1, read twice and compared; $2...: the read command
read_twice() {
	local out=$1; shift
	fbq "$@" >/dev/null || die "fastboot $*: $FB_OUT"
	fb get_staged "$out" >/dev/null || die "reading back ($*) failed"
	fbq "$@" >/dev/null || die "fastboot $*: $FB_OUT"
	fb get_staged "$out.2" >/dev/null || die "reading back ($*) failed"
	cmp -s "$out" "$out.2" || die "two reads of ($*) differ: the phone's storage is not answering steadily"
	rm -f "$out.2"
}

# the unit that holds userdata (oem gptinfo: "unit U blocks N") into UNIT and BLOCKS, and its first and last 8
# blocks into $1/head.bin and $1/tail.bin
read_gpt() {
	fbq oem gptinfo >/dev/null || die "the loader finds no table with userdata ($FB_OUT)"
	UNIT=$(printf '%s\n' "$FB_OUT" | sed -n 's/.*unit \([0-9][0-9]*\) blocks \([0-9][0-9]*\).*/\1/p' | head -1)
	BLOCKS=$(printf '%s\n' "$FB_OUT" | sed -n 's/.*unit \([0-9][0-9]*\) blocks \([0-9][0-9]*\).*/\2/p' | head -1)
	[ -n "$UNIT" ] && [ -n "$BLOCKS" ] || die "oem gptinfo said: $FB_OUT"
	read_twice "$1/head.bin" oem readunit "$UNIT" 0 8
	read_twice "$1/tail.bin" oem readunit "$UNIT" $((BLOCKS - 8)) 8
}

# gpt-plan.py's TABLE line for the table in $1/head.bin and $1/tail.bin: UD_FIRST UD_LAST DW (F..L or none)
table_of() {
	local line
	line=$(python3 "$GPTPLAN" info "$1/head.bin" "$1/tail.bin" | tee -a "${LOG:-/dev/null}" | grep '^TABLE ') ||
		die "the phone's partition table does not check (see the log)"
	UD_FIRST=$(echo "$line" | sed -n 's/.*userdata=\([0-9]*\)\.\.\([0-9]*\).*/\1/p')
	UD_LAST=$(echo "$line" | sed -n 's/.*userdata=\([0-9]*\)\.\.\([0-9]*\).*/\2/p')
	DW=$(echo "$line" | sed -n 's/.* darwin=\([^ ]*\).*/\1/p')
}

# a partition read whole, twice, into $1/NAME.img
read_part() { read_twice "$1/$2.img" oem readpart "$2"; }

carries_hakios() { LC_ALL=C grep -a -q "HKUB" "$1" && LC_ALL=C grep -a -q "XNUP" "$1"; }

# the first SIZE bytes of a partition read back ($2) are the image ($1): macOS's cmp -n compares the whole files
same_prefix() { head -c "$(stat -f %z "$1")" "$2" | cmp -s - "$1"; }

other_slot() { [ "$1" = a ] && echo b || echo a; }
