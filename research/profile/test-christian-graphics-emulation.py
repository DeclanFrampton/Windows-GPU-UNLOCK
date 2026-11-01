"""Pinned MSI graphics Stop with synthetic RAM and mocked allocation/Blt services.
No native firmware execution, GPU access, real snapshot or recovery proof.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

image = Path(sys.argv[1]).read_bytes()
if len(image) != 0x1fa0 or hashlib.sha256(image[0x2a0:0x2a0+6112]).hexdigest() != 'bbfbb62cb30815f58b751879b431fff7d0a2021568b448f873407221728fb246':
    raise ValueError('Not reviewed MSI graphics code')
rows = []
for case in ['wrong-child', 'missing-controller', 'success', 'allocate-failure', 'blt-failure', 'close-failure', 'free-failure']:
    u = Uc(UC_ARCH_X86, UC_MODE_64)
    base, ram, stubs = 0x10000000, 0x20000000, 0x30000000
    for address, size in [(base, 0x10000), (ram, 0x20000), (stubs, 0x1000)]:
        u.mem_map(address, size)
    u.mem_write(base, image)
    def put(at, value):
        u.mem_write(at, struct.pack('<Q', value))
    def get(at):
        return struct.unpack('<Q', u.mem_read(at, 8))[0]
    binding, node, services, gop, mode, info = [ram+i for i in (0x1000, 0x2000, 0x3000, 0x4000, 0x5000, 0x6000)]
    system, text, textmode, virtualmode, virtualinfo = [ram+i for i in (0x7000, 0x8000, 0x9000, 0xa000, 0xb000)]
    controller, child = 0x55550000, 0x66660000
    for at, value in [(0x1c68, child), (0x1cc0, 1), (0x1cc8, 0 if case == 'missing-controller' else node),
                      (0x1cd0, node), (0x1c80, services), (0x1c78, system), (0x1ae8, virtualmode),
                      (0x1ca0, 0), (0x1ca8, 0), (0x1cb0, 0), (0x1c50, 0)]:
        put(base+at, value)
    put(node, 0); put(node+8, 0); put(node+16, gop); put(node+24, controller)
    put(binding+0x28, 0x77770000)
    put(gop+0x18, mode); put(mode+8, info); put(gop+0x10, stubs+0x300)
    u.mem_write(info+4, struct.pack('<II', 2, 2))
    put(system+0x40, text); put(text+0x48, textmode); put(virtualmode+8, virtualinfo)
    for offset in (0x40, 0x48, 0x120):
        put(services+offset, stubs+offset)
    sp = ram+0x18008
    put(sp, stubs+0x800); put(ram+0xc000, child+8 if case == 'wrong-child' else child)
    for reg, value in [(UC_X86_REG_RSP, sp), (UC_X86_REG_RCX, binding), (UC_X86_REG_RDX, controller),
                       (UC_X86_REG_R8, 1), (UC_X86_REG_R9, ram+0xc000)]:
        u.reg_write(reg, value)
    calls = []
    def hook(engine, address, size, user):
        if any(base+a <= address < base+b for a,b in [(0x768,0x97c), (0x470,0x4d6), (0x1428,0x14ed), (0x1880,0x18ae)]):
            return
        offset = address-stubs
        if offset not in (0x40,0x48,0x120,0x300):
            raise AssertionError(f'Unexpected transfer {address:x}')
        calls.append(hex(offset)); status = 0
        if offset == 0x40:
            if engine.reg_read(UC_X86_REG_RDX) != 16:
                raise AssertionError('Unexpected snapshot allocation')
            put(engine.reg_read(UC_X86_REG_R8), ram+0x10000)
        if (offset, case) in [(0x40,'allocate-failure'), (0x300,'blt-failure'), (0x120,'close-failure'), (0x48,'free-failure')]:
            status = 0x8000000000000003
        rsp = engine.reg_read(UC_X86_REG_RSP)
        engine.reg_write(UC_X86_REG_RAX, status)
        engine.reg_write(UC_X86_REG_RIP, get(rsp)); engine.reg_write(UC_X86_REG_RSP, rsp+8)
    u.hook_add(UC_HOOK_CODE, hook)
    u.emu_start(base+0x768, stubs+0x800, count=5000)
    status = u.reg_read(UC_X86_REG_RAX)
    refused = case in ('wrong-child','missing-controller')
    if status != (0x8000000000000002 if refused else 0) or u.reg_read(UC_X86_REG_RSP) != sp+8:
        raise AssertionError('Unexpected Stop return')
    if refused and calls:
        raise AssertionError('Refused argument called a service')
    if not refused and any(get(base+at) for at in (0x1cc0,0x1cc8,0x1cd0)):
        raise AssertionError('List not unlinked')
    rows.append({'case': case, 'status': hex(status), 'calls': calls, 'snapshot_buffer_present': bool(get(base+0x1c50))})
print(json.dumps({'cases': rows, 'hardware_accessed': False, 'native_firmware_executed': False,
                  'live_graphics_release_qualified': False,
                  'finding': 'Stop can return success after ignored close/free/allocation/Blt failures; buffer presence does not prove a valid framebuffer copy.'}, indent=2))
