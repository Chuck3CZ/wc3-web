#!/usr/bin/env python3
"""Pseudo-relocations for an image without a .reloc table (war3.exe).

  ptrscan.py <image> <outdir>

genall.py and argcount.py find the code that only pointers reach (vtables,
window procedures, thread entries, callbacks) through RELOCS, the list of
fixup slots.  war3.exe has no base relocations (it always loads at
0x400000), so this rebuilds an over-approximation of them:

  * every 4-aligned dword of the non-code sections whose value lies in the
    image (the linker aligns pointer data), and
  * every immediate or displacement field of an instruction in .text (linear
    sweep) whose value lies in the image (push offset fn, mov [x], offset fn).

A slot only adds function entries when its value points into .text, so a
false hit costs at most an extra lifted function, never a wrong one.
Outputs <outdir>/relocs.txt (slot VAs) and <outdir>/seeds.txt (entry point
and exports), the same files prepare_module.py writes for a DLL.
"""
import os, struct, sys
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from capstone.x86 import X86_OP_IMM, X86_OP_MEM


def main(path, outdir):
    pe = pefile.PE(path)
    ib = pe.OPTIONAL_HEADER.ImageBase
    lo, hi = ib, ib + pe.OPTIONAL_HEADER.SizeOfImage
    slots = set()
    md = Cs(CS_ARCH_X86, CS_MODE_32); md.detail = True; md.skipdata = True
    tlo = thi = 0
    for s in pe.sections:
        va = ib + s.VirtualAddress
        data = s.get_data()[:s.Misc_VirtualSize]
        if s.Characteristics & 0x20000000:          # code
            if s.Name.rstrip(b'\0') == b'.text': tlo, thi = va, va + len(data)
            for ins in md.disasm(data, va):
                if ins.id == 0: continue            # skipdata
                for op in ins.operands:
                    if op.type == X86_OP_IMM and ins.imm_offset and ins.imm_size == 4:
                        v = op.imm & 0xffffffff
                        if lo <= v < hi: slots.add(ins.address + ins.imm_offset)
                    elif op.type == X86_OP_MEM and ins.disp_offset and ins.disp_size == 4:
                        v = op.mem.disp & 0xffffffff
                        if lo <= v < hi: slots.add(ins.address + ins.disp_offset)
        else:
            for o in range(0, len(data) - 3, 4):
                v = struct.unpack_from('<I', data, o)[0]
                if lo <= v < hi: slots.add(va + o)
    seeds = {ib + pe.OPTIONAL_HEADER.AddressOfEntryPoint}
    if hasattr(pe, 'DIRECTORY_ENTRY_EXPORT'):
        for e in pe.DIRECTORY_ENTRY_EXPORT.symbols:
            v = ib + e.address
            if tlo <= v < thi: seeds.add(v)
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, 'relocs.txt'), 'w') as f:
        f.write('\n'.join(f'{a:08x}' for a in sorted(slots)))
    with open(os.path.join(outdir, 'seeds.txt'), 'w') as f:
        f.write('\n'.join(f'{a:08x}' for a in sorted(seeds)))
    print(f"ptrscan: {path}: {len(slots)} pointer slots, {len(seeds)} seeds (entry + exports in .text)")


if __name__ == '__main__':
    if len(sys.argv) != 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
