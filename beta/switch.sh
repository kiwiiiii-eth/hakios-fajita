#!/bin/bash
# HakiOS on the OnePlus 6T, Beta 0.8.1: which system the phone starts, once install.sh has put HakiOS in a slot of its own.
#
#   ./switch.sh android     Android's slot active: the phone starts Android
#   ./switch.sh hakios      HakiOS's slot active: the phone starts iOS
#
# The phone in Android (USB debugging on), or in fastboot (hold Power + Volume Up). From iOS: hold Power + Volume Up
# until the fastboot screen. Nothing is erased or written but which slot is active.
set -e
ME=switch
. "$(cd "$(dirname "$0")" && pwd)/lib-install.sh"
case "${1:-}" in android|hakios) ;; *) echo "usage: ./switch.sh android|hakios" >&2; exit 2 ;; esac
command -v fastboot >/dev/null || die "no fastboot (brew install android-platform-tools)"
to_abl
SERIAL=$(fastboot devices | awk '$2=="fastboot" && $1!="xnuloader" {print $1; exit}')
BK=$BACKUPS/$SERIAL
TARGET=$(recorded_slot "$BK")
[ -n "$TARGET" ] || die "no record of an install on this phone ($BK)"
[ "$1" = hakios ] && SLOT=$TARGET || SLOT=$(other_slot "$TARGET")
fbq set_active "$SLOT" >/dev/null || die "fastboot set_active $SLOT failed: $FB_OUT"
[ "$(getvar current-slot)" = "$SLOT" ] || die "ABL did not make slot $SLOT active"
fbq reboot >/dev/null || true
echo "$ME: slot $SLOT active: the phone starts $( [ "$1" = hakios ] && echo iOS || echo Android )"
