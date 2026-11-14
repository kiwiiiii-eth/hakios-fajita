#!/bin/bash
# Make the Beta test kit: what a tester cannot build without Xcode, prebuilt from this tree, and the scripts that make
# the rest on their own Mac from their own IPSW and phone (beta/setup.sh, beta/run.sh).
#   scripts/mk-beta-kit.sh [VERSION]   → $ROOT/out/kit/hakios-6t-VERSION.tar.gz (VERSION: v0.3-beta)
#
# In it, and only these: the kernel (XNU, APSL-2.0, with this port's drivers), a BLANK loader (mkidentity.py --blank:
# no Apple data; setup.sh fills in the identity from the tester's IPSW), our user-space programs (userland/obj: our
# sources, Mesa's libOSMesa under the MIT licence), the scripts, the notices. NOT in it: anything of the IPSW, any
# firmware, any key (ssh/), the system or root image. The kit is checked for those before it is packed.
set -e
REPO=$(cd -P "$(dirname "$0")/.." && pwd); ROOT=${HAKIOS_ROOT:-$(dirname "$REPO")}; K=$ROOT/hakios-xnu-kernel
VERSION=${1:-v0.3-beta}
NAME=hakios-6t-$VERSION
OUT=$ROOT/out/kit/$NAME
export PATH="$ROOT/hostbin:$REPO/hostbin:$PATH"

[ -f "$K/hakios-kernel" ] || { echo "mk-beta-kit.sh: no kernel: make kernel first" >&2; exit 1; }
[ -f "$K/userland/obj/libhakios.bt.dylib" ] && [ -f "$K/userland/obj/libOSMesa.8.dylib" ] && [ -f "$K/userland/obj/aks_restore" ] ||
	{ echo "mk-beta-kit.sh: userland/obj is not a BT=1 GL=1 build: run userland/build.sh as for a run first" >&2; exit 1; }
want=$(cd "$K" && python3 tools/hakios-config.py builtin --sha)
have=$(strings -a "$K/hakios-kernel" | grep -m1 '^hakios_builtin_args_sha=' | cut -d= -f2)
[ "$have" = "$want" ] || { echo "mk-beta-kit.sh: the kernel's built-in arguments (${have:-none}) are not the configuration's ($want): make kernel" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/prebuilt/userland" "$OUT/notices"
cp "$K/hakios-kernel" "$OUT/prebuilt/hakios-kernel"
echo "$want" > "$OUT/prebuilt/hakios-kernel.args-sha"

# the blank loader, built in a copy of xnuloader/ so that this tree's own identity.h (made from an IPSW) is not touched
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp -R "$K/xnuloader" "$T/xnuloader"
rm -f "$T/xnuloader/identity.h" "$T/xnuloader/loader.efi" "$T/xnuloader/loader.obj"
python3 "$T/xnuloader/mkidentity.py" --blank > "$T/xnuloader/identity.h"
(cd "$T/xnuloader" && ./build.sh >/dev/null 2>&1) || { echo "mk-beta-kit.sh: the blank loader did not build" >&2; exit 1; }
cp "$T/xnuloader/loader.efi" "$OUT/prebuilt/loader.blank.efi"

for f in "$K"/userland/obj/*; do
	[ -f "$f" ] || continue             # (obj/macinc: the macOS SDK's libproc headers that src/socks.c is built with)
	case "$f" in *.o|*.h|*.new) continue ;; esac
	cp "$f" "$OUT/prebuilt/userland/"
done
cp "$K/userland/hello" "$OUT/prebuilt/userland/hello"      # (built beside obj/, not in it; PREBUILT=1 takes it from prebuilt/)
cp "$REPO/beta/setup.sh" "$REPO/beta/run.sh" "$REPO/beta/README.md" "$OUT/"
cp "$REPO/beta/NOTICE.md" "$OUT/notices/"
chmod +x "$OUT/setup.sh" "$OUT/run.sh"

# nothing that must not leave this machine
bad=
grep -l -a -E "iPhone10,3|D22AP|d22ap" "$OUT/prebuilt/loader.blank.efi" >/dev/null && bad="$bad the loader carries an identity;"
find "$OUT" \( -name "*.mdt" -o -name "*.mbn" -o -name "*.b[0-9][0-9]" -o -name "*.tlv" -o -name "crnv*" -o -name "*ed25519*" \
	-o -name "authorized_keys" -o -name "*.apfs" -o -name "*.ipsw" -o -name "*.im4p" \) | grep -q . && bad="$bad firmware, a key or an image;"
grep -l -a -E "BEGIN OPENSSH PRIVATE KEY|PRIVATE KEY-----" -r "$OUT" >/dev/null && bad="$bad a private key;"
[ -z "$bad" ] || { echo "mk-beta-kit.sh: NOT PACKED:$bad" >&2; exit 1; }

(cd "$OUT" && find . -type f ! -name SHA256SUMS | sort | xargs shasum -a 256 > SHA256SUMS)
(cd "$(dirname "$OUT")" && rm -f "$NAME.tar.gz" && tar -czf "$NAME.tar.gz" "$NAME")
ls -la "$(dirname "$OUT")/$NAME.tar.gz"
