"""Exercise compiled membership audit with synthetic firmware services, never hardware.
Build test-msi-membership.c as an EFI-format container first; pass that path here.
Requires developer-only Unicorn. Does not boot or execute firmware natively.
"""
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE, UC_HOOK_MEM_READ
from unicorn.x86_const import (UC_X86_REG_RSP, UC_X86_REG_RIP, UC_X86_REG_RAX,
                              UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9)

data = Path(sys.argv[1]).read_bytes()
pe = struct.unpack_from('<I', data, 60)[0]
opt = pe + 24
entry = struct.unpack_from('<I', data, opt + 16)[0]
table = opt + struct.unpack_from('<H', data, pe + 20)[0]
unsupported = 0x8000000000000003
rows = []
cases = ['success', 'wrong-child', 'two-nodes', 'mmio-node', 'out-of-range',
         'unaligned-node', 'map-error', 'short-stride', 'overflow-pages',
         'physical-gop', 'missing-gop', 'record-error', 'read-protected', 'wrong-count', 'wrong-tail', 'wrong-previous']
for case in cases:
    u = Uc(UC_ARCH_X86, UC_MODE_64)
    image, stack, stubs, ram = 0x10000000, 0x20000000, 0x30000000, 0x40000000
    for start, size in [(image, 0x20000), (stack, 0x10000), (stubs, 0x10000), (ram, 0x20000)]:
        u.mem_map(start, size)
    for i in range(struct.unpack_from('<H', data, pe + 6)[0]):
        section = table + 40 * i
        rva, size, raw = struct.unpack_from('<III', data, section + 12)
        if size:
            u.mem_write(image + rva, data[raw:raw + size])
    def put(at, value):
        u.mem_write(at, struct.pack('<Q', value))
    def get(at):
        return struct.unpack('<Q', u.mem_read(at, 8))[0]
    system, services, base, buffer, node = ram, ram + 0x1000, ram + 0x2000, ram + 0xa000, ram + 0x12000
    controller, console = 0x55550000, 0x66660000
    put(system + 0x60, services)
    put(system + 0x38, console)
    put(base + 0x6110, console if case != 'wrong-child' else console + 8)
    put(base + 0x6288, node if case != 'unaligned-node' else node + 1)
    put(base + 0x6280, 2 if case == 'wrong-count' else 1)
    put(base + 0x6290, node + 8 if case == 'wrong-tail' else node)
    put(node, 0 if case != 'two-nodes' else node + 0x40)
    put(node+8, node+0x40 if case == 'wrong-previous' else 0)
    put(node + 24, controller)
    for offset in (0x38, 0x40, 0x48, 0x98):
        put(services + offset, stubs + offset)
    sp = stack + 0x8008
    put(sp, stubs + 0x1000)
    for reg, value in [(UC_X86_REG_RSP, sp), (UC_X86_REG_RCX, system),
                       (UC_X86_REG_RDX, base), (UC_X86_REG_R8, 0x7000),
                       (UC_X86_REG_R9, stubs + 0x200)]:
        u.reg_write(reg, value)
    events, reads = [], []
    def read_hook(engine, access, address, size, value, user):
        if node <= address < node + 32:
            reads.append(address)
    def code_hook(engine, address, size, user):
        if image <= address < image + 0x20000:
            return
        rcx, rdx, r8 = [engine.reg_read(r) for r in (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8)]
        status = 0
        if address == stubs + 0x40:
            put(r8, buffer)
        elif address == stubs + 0x38:
            descriptor = bytearray(40)
            struct.pack_into('<I', descriptor, 0, 11 if case == 'mmio-node' else 4)
            struct.pack_into('<Q', descriptor, 8, node + 16 if case == 'out-of-range' else node)
            struct.pack_into('<Q', descriptor, 24, (2**64 - 1) if case == 'overflow-pages' else 1)
            struct.pack_into('<Q', descriptor, 32, 0x2000 if case == 'read-protected' else 0)
            engine.mem_write(rdx, bytes(descriptor))
            put(rcx, 40)
            put(engine.reg_read(UC_X86_REG_R9), 8 if case == 'short-stride' else 40)
            status = unsupported if case == 'map-error' else 0
        elif address == stubs + 0x48:
            if rcx != buffer:
                raise AssertionError('Unexpected free')
        elif address == stubs + 0x98:
            if rcx != controller:
                raise AssertionError('Unexpected controller')
            is_gop = bytes(engine.mem_read(rdx, 4)) == bytes.fromhex('dea94290')
            status = unsupported if (is_gop and case == 'missing-gop') or (not is_gop and case != 'physical-gop') else 0
            if status == 0:
                put(r8, 0x77770000)
        elif address == stubs + 0x200:
            name = bytes(engine.mem_read(rdx, 100)).split(b'\0', 1)[0].decode()
            events.append((name, r8))
            status = unsupported if case == 'record-error' else 0
        else:
            raise AssertionError(f'Unmocked control transfer {address:x}')
        rsp = engine.reg_read(UC_X86_REG_RSP)
        engine.reg_write(UC_X86_REG_RAX, status)
        engine.reg_write(UC_X86_REG_RIP, get(rsp))
        engine.reg_write(UC_X86_REG_RSP, rsp + 8)
    u.hook_add(UC_HOOK_CODE, code_hook)
    u.hook_add(UC_HOOK_MEM_READ, read_hook)
    u.emu_start(image + entry, stubs + 0x1000, count=10000)
    status = u.reg_read(UC_X86_REG_RAX)
    if (status == 0) != (case == 'success') or u.reg_read(UC_X86_REG_RSP) != sp + 8:
        raise AssertionError(f'Unexpected result {case}: {status:x}')
    if case in ('mmio-node', 'out-of-range', 'unaligned-node', 'map-error', 'short-stride', 'overflow-pages', 'read-protected') and reads:
        raise AssertionError(f'Unsafe node was read: {case}')
    rows.append({'case': case, 'status': hex(status), 'node_reads': len(reads), 'events': events})
print(json.dumps({'cases': rows, 'hardware_accessed': False, 'native_firmware_executed': False}, indent=2))
