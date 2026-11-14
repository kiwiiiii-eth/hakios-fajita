#!/usr/bin/env python3
"""The microphone's second (adsp8=225, step 25: "MICPCM" lines of base64 in a run's log) as WAV files.

usage: micpcm2wav.py LOG OUT.wav     -> OUT.wav (as heard) and OUT-loud.wav (scaled to a peak of -3 dBFS)
"""
import base64
import re
import struct
import sys
import wave


def main():
    log, out = sys.argv[1], sys.argv[2]
    lines = {}
    rate = 48000
    for raw in open(log, 'rb').read().decode('latin-1').splitlines():
        m = re.search(r'MICPCM begin (\d+) frames, (\d+) Hz', raw)
        if m:
            rate = int(m.group(2))
            continue
        m = re.search(r'MICPCM (\d+) ([A-Za-z0-9+/=]+)\s*$', raw)
        if m:
            lines[int(m.group(1))] = m.group(2)
    if not lines:
        sys.exit('micpcm2wav: no MICPCM lines in ' + log)
    missing = [n for n in range(max(lines) + 1) if n not in lines]
    data = b''.join(base64.b64decode(lines.get(n, '')) if n in lines else b'\0' * 72 for n in range(max(lines) + 1))
    samples = list(struct.unpack('<%dh' % (len(data) // 2), data[:len(data) // 2 * 2]))
    peak = max(1, max(abs(s) for s in samples))
    rms = (sum(s * s for s in samples) / len(samples)) ** 0.5
    for path, scale in ((out, 1.0), (out.replace('.wav', '-loud.wav'), 0.707 * 32767 / peak)):
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(struct.pack('<%dh' % len(samples), *(max(-32768, min(32767, int(s * scale))) for s in samples)))
    print('micpcm2wav: %d samples (%.2f s at %d Hz), RMS %.1f, peak %d; %d of %d lines missing -> %s and its -loud copy (x%.0f)'
          % (len(samples), len(samples) / rate, rate, rms, peak, len(missing), max(lines) + 1, out, 0.707 * 32767 / peak))


if __name__ == '__main__':
    main()
