"""Exact pinned text Stop with one synthetic controller; mocked firmware services.
The mode-rebuild helper is exercised on its HandleProtocol refusal path only.
This is not qualification of live protocol services or all cleanup paths.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

image = Path(sys.argv[1]).read_bytes()
if hashlib.sha256(image[0x2a0:0x2a0+21904]).hexdigest() != '3a14de3d645d704fdd327e9e814c7b8928d98ee734d777823d3abe389d628aaa':
    raise ValueError('Not the reviewed MSI text code')
rows = []
for case in ['other-state-present', 'cleanup-empty-buffers', 'close-failure', 'free-failure']:
    u = Uc(UC_ARCH_X86, UC_MODE_64)
    base, stack, stubs = 0x10000000, 0x20000000, 0x30000000
    for address, size in [(base, 0x10000), (stack, 0x10000), (stubs, 0x1000)]:
        u.mem_map(address, size)
    u.mem_write(base, image)
    def put(address, value):
        u.mem_write(address, struct.pack('<Q', value))
    def get(address):
        return struct.unpack('<Q', u.mem_read(address, 8))[0]
    binding, node, state, services = stack+0x1000, stack+0x2000, stack+0x3000, stack+0x4000
    controller, child = 0x55550000, 0x66660000
    put(base+0x6110, child)
    put(base+0x6280, 1)
    put(base+0x6288, node)
    put(base+0x6290, node)
    put(base+0x61d0, state)
    put(state+0x40, 0 if case == 'cleanup-empty-buffers' else 1)
    for at in (0x6160, 0x6168, 0x6170, 0x6178):
        put(base+at, 0)
    put(base+0x61c0, services)
    put(binding+0x28, 0x77770000)
    put(node, 0)
    put(node+8, 0)
    put(node+24, controller)
    put(stack+0x5000, child)
    for offset in (0x48, 0x98, 0x120, 0x150):
        put(services+offset, stubs+offset)
    sp = stack+0x8008
    put(sp, stubs+0x800)
    for reg, value in [(UC_X86_REG_RSP, sp), (UC_X86_REG_RCX, binding),
                       (UC_X86_REG_RDX, controller), (UC_X86_REG_R8, 1),
                       (UC_X86_REG_R9, stack+0x5000)]:
        u.reg_write(reg, value)
    calls = []
    def hook(engine, address, size, user):
        if any(base+a <= address < base+b for a, b in [(0x10bc, 0x1280), (0x4da4, 0x4dd8), (0x420c, 0x42f3)]):
            return
        offset = address-stubs
        if offset not in (0x48, 0x98, 0x120, 0x150):
            raise AssertionError(f'Unexpected helper/service {address:x}')
        calls.append(hex(offset))
        if offset == 0x48 and engine.reg_read(UC_X86_REG_RCX) != node:
            raise AssertionError('Unexpected free')
        status = 0
        if offset in (0x98, 0x150) or (offset == 0x120 and case == 'close-failure'):
            status = 0x8000000000000003
        if offset == 0x48 and case == 'free-failure':
            status = 0x8000000000000007
        rsp = engine.reg_read(UC_X86_REG_RSP)
        engine.reg_write(UC_X86_REG_RAX, status)
        engine.reg_write(UC_X86_REG_RIP, get(rsp))
        engine.reg_write(UC_X86_REG_RSP, rsp+8)
    u.hook_add(UC_HOOK_CODE, hook)
    u.emu_start(base+0x10bc, stubs+0x800, count=5000)
    status = u.reg_read(UC_X86_REG_RAX)
    expected = 0x8000000000000007 if case == 'free-failure' else 0
    if status != expected or any(get(base+at) for at in (0x6280, 0x6288, 0x6290)):
        raise AssertionError('Unexpected return or list unlink')
    if calls != ['0x120', '0x120', '0x98', '0x48', '0x150']:
        raise AssertionError('Unexpected firmware call order')
    rows.append({'case': case, 'status': hex(status), 'list_empty': True, 'calls': calls})
print(json.dumps({'cases': rows, 'hardware_accessed': False, 'native_firmware_executed': False,
                  'live_removal_qualified': False,
                  'finding': 'CloseProtocol and OpenProtocol errors do not determine Stop return; post-call ownership checks are required.'}, indent=2))
