#!/usr/bin/env python3
# 把預編 hakios-kernel 的 GIC 虛擬計時器中斷 27 改成 SDM845 的 19（PPI 3）。只改 5 條指令，先驗舊值。
#   patch-vtimer.py in-kernel out-kernel
import sys, struct
VM, FO = 0xfffffff007294000, 2686976            # __TEXT_EXEC vmaddr / fileoff
P = [  # (va, old, new, 說明)
    (0xfffffff007457fb8, 0x72A10008, 0x72A00108, 'movk w8,#0x800,lsl16 -> #0x8 (mine |= 1<<19)'),
    (0xfffffff007457fc0, 0x52A10008, 0x52A00108, 'mov w8,#1<<27 -> #1<<19'),
    (0xfffffff007457fe4, 0xD123952A, 0xD123B52A, 'IPRIORITYR(27) -> IPRIORITYR(19)'),
    (0xfffffff00745813c, 0x71006E9F, 0x71004E9F, 'handler: cmp intid,#27 -> #19'),
    (0xfffffff00745805c, 0x52800369, 0x52800269, 'kprintf: 27 -> 19'),
]
d = bytearray(open(sys.argv[1], 'rb').read())
for va, old, new, what in P:
    o = va - VM + FO
    cur = struct.unpack_from('<I', d, o)[0]
    if cur != old:
        sys.exit(f'{va:x}: 是 {cur:08x}，不是預期的 {old:08x}，停止')
    struct.pack_into('<I', d, o, new)
    print(f'{va:x} @{o:#x}: {old:08x} -> {new:08x}  {what}')
open(sys.argv[2], 'wb').write(d)
