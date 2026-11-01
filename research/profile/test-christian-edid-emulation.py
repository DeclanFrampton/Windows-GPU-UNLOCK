"""Pinned EDID-present Stop branch only; fallback is detected, never emulated.
Requires developer Unicorn. No native firmware execution or hardware access.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

image=Path(sys.argv[1]).read_bytes()
if len(image)!=0x9000 or hashlib.sha256(image[0x1000:0x1000+14178]).hexdigest()!='333b27054df5e7d197238b860fe04e8e618712b533d1608ee9056e1b2435fcb2':
    raise ValueError('Not reviewed MSI EDID code')
rows=[]
for case in ['success','close-failure','open-fallback-boundary']:
    u=Uc(UC_ARCH_X86,UC_MODE_64);base,ram,stub=0x10000000,0x20000000,0x30000000
    for at,size in [(base,0x10000),(ram,0x10000),(stub,0x1000)]:u.mem_map(at,size)
    u.mem_write(base,image)
    def put(at,value):u.mem_write(at,struct.pack('<Q',value))
    def get(at):return struct.unpack('<Q',u.mem_read(at,8))[0]
    binding,services,sp=ram+0x1000,ram+0x2000,ram+0x8008
    put(base+0x5520,services);put(binding+0x28,0x77770000);put(sp,stub+0x800)
    put(services+0x118,stub+0x118);put(services+0x120,stub+0x120)
    u.mem_write(base+0x5501,b'\x7f')
    for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,binding),(UC_X86_REG_RDX,0x55550000),(UC_X86_REG_R8,0),(UC_X86_REG_R9,0)]:u.reg_write(reg,value)
    calls=[];fallback=[]
    def hook(engine,address,size,user):
        if address==base+0x1507:
            fallback.append(True);engine.emu_stop();return
        if base+0x149c<=address<base+0x15d1:return
        offset=address-stub
        if offset not in (0x118,0x120):raise AssertionError('Unexpected transfer')
        calls.append(hex(offset));status=0
        if offset==0x118:put(engine.reg_read(UC_X86_REG_R8),0x77770000)
        if (offset,case) in [(0x118,'open-fallback-boundary'),(0x120,'close-failure')]:status=0x8000000000000003
        rsp=engine.reg_read(UC_X86_REG_RSP);engine.reg_write(UC_X86_REG_RAX,status)
        engine.reg_write(UC_X86_REG_RIP,get(rsp));engine.reg_write(UC_X86_REG_RSP,rsp+8)
    u.hook_add(UC_HOOK_CODE,hook);u.emu_start(base+0x149c,stub+0x800,count=2000)
    if case=='open-fallback-boundary':
        if not fallback or calls!=['0x118']:raise AssertionError('Fallback boundary not reached')
    else:
        expected=0 if case=='success' else 0x8000000000000003
        if u.reg_read(UC_X86_REG_RAX)!=expected or u.reg_read(UC_X86_REG_RSP)!=sp+8 or bytes(u.mem_read(base+0x5501,1))!=b'\0':raise AssertionError('Unexpected return/flag')
    rows.append({'case':case,'calls':calls,'fallback_detected_not_executed':bool(fallback)})
print(json.dumps({'cases':rows,'hardware_accessed':False,'native_firmware_executed':False,
                  'alternate_protocol_paths_qualified':False},indent=2))
