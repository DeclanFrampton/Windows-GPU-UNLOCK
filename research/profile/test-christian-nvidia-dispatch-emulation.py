"""Limited exact NVIDIA Stop dispatcher paths with synthetic empty context.
GPU teardown callbacks are not modeled or qualified; never executes natively.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

data=Path(sys.argv[1]).read_bytes()
if len(data)!=0x2b700 or hashlib.sha256(data[0x280:0x280+146818]).hexdigest()!='d045cee2113e461c7c678ec21542b1d0f18356765c0fc6a0bf2dcf824088e011':raise ValueError('Not pinned NVIDIA code')
rows=[]
for case in ['child-private-open-failure','parent-private-open-failure','empty-parent-success','parent-uninstall-failure','flagged-context-boundary']:
    u=Uc(UC_ARCH_X86,UC_MODE_64);base,ram,stubs=0x10000000,0x20000000,0x30000000
    for at,size in [(base,0x30000),(ram,0x10000),(stubs,0x1000)]:u.mem_map(at,size)
    u.mem_write(base,data)
    def put(at,value):u.mem_write(at,struct.pack('<Q',value))
    def get(at):return struct.unpack('<Q',u.mem_read(at,8))[0]
    binding,context,services,sp=ram+0x1000,ram+0x2000,ram+0x3000,ram+0x8008
    put(base+0x285b0,services);put(binding+0x28,0x77770000);put(sp,stubs+0x800)
    for offset in (0x48,0x90,0x118):put(services+offset,stubs+offset)
    if case=='flagged-context-boundary':u.mem_write(context+0x98,b'\1')
    for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,binding),(UC_X86_REG_RDX,0x55550000),(UC_X86_REG_R8,1 if case.startswith('child') else 0),(UC_X86_REG_R9,ram+0x4000)]:u.reg_write(reg,value)
    calls=[];boundary=[]
    def hook(engine,address,size,user):
        if address==base+0x72a:
            boundary.append(True);engine.emu_stop();return
        if any(base+a<=address<base+b for a,b in [(0x698,0x774),(0x1620,0x17f4),(0x135c,0x13ee),(0x113c,0x11c8)]):return
        offset=address-stubs
        if offset not in (0x48,0x90,0x118):raise AssertionError(f'Unexpected teardown callback {case} {address:x}')
        calls.append(hex(offset));status=0
        if offset==0x118:put(engine.reg_read(UC_X86_REG_R8),context)
        if (offset==0x118 and case.endswith('open-failure')) or (offset==0x90 and case=='parent-uninstall-failure'):status=0x8000000000000003
        if offset==0x48 and engine.reg_read(UC_X86_REG_RCX)!=context:raise AssertionError('Unexpected free')
        rsp=engine.reg_read(UC_X86_REG_RSP);engine.reg_write(UC_X86_REG_RAX,status)
        engine.reg_write(UC_X86_REG_RIP,get(rsp));engine.reg_write(UC_X86_REG_RSP,rsp+8)
    u.hook_add(UC_HOOK_CODE,hook);u.emu_start(base+0x698,stubs+0x800,count=5000)
    if case=='flagged-context-boundary':
        if not boundary or calls!=['0x118']:raise AssertionError('Missing flagged callback boundary')
    else:
        expected=0 if case=='empty-parent-success' else 0x8000000000000003
        if u.reg_read(UC_X86_REG_RAX)!=expected or u.reg_read(UC_X86_REG_RSP)!=sp+8:raise AssertionError('Wrong dispatch return')
    rows.append({'case':case,'calls':calls,'private_callback_detected_not_executed':bool(boundary)})
print(json.dumps({'cases':rows,'hardware_accessed':False,'native_firmware_executed':False,'full_teardown_qualified':False},indent=2))
