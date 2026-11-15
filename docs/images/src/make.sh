#!/bin/bash
# Remake the pictures in docs/images/ (macOS): the boot screen from the loader's own drawing code (harness.c includes
# hakios-xnu-kernel's xnuloader/bootscreen.c), the diagrams from the HTML here through a headless Chromium (Microsoft
# Edge or Google Chrome), trimmed with Pillow.
#   docs/images/src/make.sh
# Needs hakios-xnu-kernel next to this repository (or K=...), Pillow, and the fonts in docs/images/src/fonts/:
# inter.ttf (Inter's InterVariable.ttf) and mono.ttf (JetBrains Mono's JetBrainsMono[wght].ttf), both SIL OFL 1.1.
set -e
SRC=$(cd "$(dirname "$0")" && pwd)
IMG=$(dirname "$SRC")
K=${K:-$(cd "$SRC/../../.." && pwd)/../hakios-xnu-kernel}
B=$(mktemp -d /tmp/hakios-docimg.XXXXXX)
cp "$SRC"/*.html "$SRC"/*.css "$SRC"/*.js "$B/"
ln -s "$SRC/fonts" "$B/fonts"
cc -O1 -I "$K/xnuloader" -o "$B/harness" "$SRC/harness.c"
python3 - "$B" <<'PYEOF'
import subprocess, sys, zlib, struct
b = sys.argv[1]
def png(raw, out, w=1080, h=2340):
    rows = bytearray()
    for y in range(h):
        rows.append(0); row = raw[y*w*4:(y+1)*w*4]
        for x in range(w): rows += bytes((row[x*4+2], row[x*4+1], row[x*4]))
    c = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(out, 'wb').write(b'\x89PNG\r\n\x1a\n' + c(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
                          c(b'IDAT', zlib.compress(bytes(rows), 9)) + c(b'IEND', b''))
for mode, name in (('1', 'bootscreen'), ('2', 'bootscreen-log')):
    png(subprocess.run([b + '/harness', mode], capture_output=True, check=True).stdout, f'{b}/{name}.png')
PYEOF
CHROME=${CHROME:-"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"}
[ -x "$CHROME" ] || CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot() {
	"$CHROME" --headless=new --user-data-dir="$B/profile" --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
		--default-background-color=00000000 --virtual-time-budget=3000 --window-size="$2" --screenshot="$B/$3.png" \
		"file://$B/$1" >/dev/null 2>&1
}
shot boot-flow.html 1240,500 boot-flow-light
shot "boot-flow.html?dark" 1240,500 boot-flow-dark
shot storage.html 1240,500 storage-light
shot "storage.html?dark" 1240,500 storage-dark
shot phones.html 820,740 bootscreen-phones
python3 - "$B" "$IMG" <<'PYEOF'
import shutil, sys
from PIL import Image
b, img = sys.argv[1:]
for n in ('bootscreen', 'bootscreen-log'):
    shutil.copy(f'{b}/{n}.png', f'{img}/{n}.png')
for n in ('boot-flow-light', 'boot-flow-dark', 'storage-light', 'storage-dark', 'bootscreen-phones'):
    im = Image.open(f'{b}/{n}.png').convert('RGBA')
    im.crop(im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()).save(f'{img}/{n}.png', optimize=True)
PYEOF
echo "make.sh: pictures in $IMG (the work files are in $B)"
