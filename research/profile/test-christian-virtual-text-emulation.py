"""Pinned MSI virtual renderer Stop in CPU emulation with mocked boot services.
No native firmware execution, hardware access or live release qualification.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

image = Path(sys.argv[1]).read_bytes()
if len(image) != 0x39a0 or hashlib.sha256(image[0x2a0:0x2a0+7232]).hexdigest() != '654ca7fec19bf03dabe804d0d81d47dc810788be59dea03d8c24c727281494ac':
    raise ValueError('Not the reviewed MSI virtual text image')
rows = []
for case in ['success', 'open-failure', 'uninstall-failure', 'close-failure', 'free-failure']:
    u = Uc(UC_ARCH_X86, UC_MODE_64)
    base, stack, stubs = 0x10000000, 0x20000000, 0x30000000
    for address, size in [(base, 0x10000), (stack, 0x10000), (stubs, 0x1000)]:
        u.mem_map(address, size)
    u.mem_write(base, image)
    def put(at, value):
        u.mem_write(at, struct.pack('<Q', value))
    def get(at):
        return struct.unpack('<Q', u.mem_read(at, 8))[0]
    binding, interface, services = stack+0x1000, stack+0x2000, stack+0x4000
    put(base+0x3638, services)
    put(binding+0x28, 0x77770000)
    put(interface+0x68, stack+0x6000)
    put(interface+0x48, stack+0x7000)
    for offset in (0x48, 0x118, 0x120, 0x150):
        put(services+offset, stubs+offset)
    sp = stack+0x8008
    put(sp, stubs+0x800)
    for reg, value in [(UC_X86_REG_RSP, sp), (UC_X86_REG_RCX, binding),
                       (UC_X86_REG_RDX, 0x55550000), (UC_X86_REG_R8, 0), (UC_X86_REG_R9, 0)]:
        u.reg_write(reg, value)
    calls, frees = [], []
    def hook(engine, address, size, user):
        if base+0xa08 <= address < base+0xb15:
            return
        offset = address-stubs
        if offset not in (0x48, 0x118, 0x120, 0x150):
            raise AssertionError('Unexpected transfer')
        calls.append(hex(offset))
        status = 0
        if offset == 0x118:
            put(engine.reg_read(UC_X86_REG_R8), interface)
        if offset == 0x48:
            frees.append(engine.reg_read(UC_X86_REG_RCX))
        if (offset, case) in [(0x118, 'open-failure'), (0x150, 'uninstall-failure'), (0x120, 'close-failure'), (0x48, 'free-failure')]:
            status = 0x8000000000000003
        rsp = engine.reg_read(UC_X86_REG_RSP)
        engine.reg_write(UC_X86_REG_RAX, status)
        engine.reg_write(UC_X86_REG_RIP, get(rsp))
        engine.reg_write(UC_X86_REG_RSP, rsp+8)
    u.hook_add(UC_HOOK_CODE, hook)
    u.emu_start(base+0xa08, stubs+0x800, count=5000)
    status = u.reg_read(UC_X86_REG_RAX)
    expected = 0x8000000000000013 if case == 'open-failure' else 0x8000000000000003 if case == 'uninstall-failure' else 0
    if status != expected or u.reg_read(UC_X86_REG_RSP) != sp+8:
        raise AssertionError('Unexpected return')
    if case not in ('open-failure', 'uninstall-failure') and frees != [stack+0x6000, stack+0x7000, interface]:
        raise AssertionError('Unexpected free sequence')
    if case in ('open-failure', 'uninstall-failure') and frees:
        raise AssertionError('Freed after refused open/uninstall')
    rows.append({'case': case, 'status': hex(status), 'calls': calls, 'free_count': len(frees)})
print(json.dumps({'cases': rows, 'hardware_accessed': False, 'native_firmware_executed': False,
                  'live_release_qualified': False}, indent=2))
