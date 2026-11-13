#!/usr/bin/env python3
# 讀 DTB：列出 compatible 含關鍵字的節點與其 reg / 指定屬性。用法：dtq.py file.dtb 關鍵字 [屬性...]
import sys, struct
d = open(sys.argv[1], 'rb').read(); key = sys.argv[2].encode(); extra = sys.argv[3:]
_, _, off_s, off_str = struct.unpack('>IIII', d[:16])
def s(o): e = d.index(b'\0', off_str + o); return d[off_str + o:e].decode()
p = off_s; path = []; props = [{}]
def show(path, pr):
    c = pr.get('compatible', b'')
    if key in c or key in '/'.join(path).encode():
        print('/'.join(path) or '/', c.replace(b'\0', b' ').decode(errors='replace'))
        for n in ['reg', 'reg-names'] + extra:
            if n in pr:
                v = pr[n]
                if n.endswith('names') or (v and v[-1:] == b'\0' and all(32 <= x < 127 or x == 0 for x in v)):
                    print('   ', n, v.replace(b'\0', b' ').decode())
                elif len(v) % 4 == 0:
                    print('   ', n, ' '.join(hex(x) for x in struct.unpack('>%dI' % (len(v) // 4), v)))
while p < len(d):
    t = struct.unpack('>I', d[p:p + 4])[0]; p += 4
    if t == 1:
        e = d.index(b'\0', p); path.append(d[p:e].decode()); p = (e + 4) & ~3; props.append({})
    elif t == 2:
        show(path, props[-1]); path.pop(); props.pop()
    elif t == 3:
        ln, no = struct.unpack('>II', d[p:p + 8]); p += 8; props[-1][s(no)] = d[p:p + ln]; p = (p + ln + 3) & ~3
    elif t == 9: break
