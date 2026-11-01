"""Compiled EDID/NVIDIA metadata helpers with synthetic protocol inventories only."""
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

data=Path(sys.argv[1]).read_bytes();nv=len(sys.argv)>2 and sys.argv[2]=='nvidia'
pe=struct.unpack_from('<I',data,60)[0];opt=pe+24;entry=struct.unpack_from('<I',data,opt+16)[0]
table=opt+struct.unpack_from('<H',data,pe+20)[0]
cases=(['success','missing-child','wrong-child','wrong-parent-owner','duplicate-child','wrong-count','open-error','too-many-opens'] if nv else
       ['success','absent','absent-with-get','stale-owner-after','wrong-handle','two-handles','wrong-agent','wrong-count','open-error','too-many-opens'])
rows=[]
for case in cases:
    u=Uc(UC_ARCH_X86,UC_MODE_64);image,ram,stubs=0x10000000,0x20000000,0x30000000
    for start,size in [(image,0x20000),(ram,0x20000),(stubs,0x1000)]:u.mem_map(start,size)
    for i in range(struct.unpack_from('<H',data,pe+6)[0]):
        rva,size,raw=struct.unpack_from('<III',data,table+40*i+12)
        if size:u.mem_write(image+rva,data[raw:raw+size])
    def put(at,value):u.mem_write(at,struct.pack('<Q',value))
    def get(at):return struct.unpack('<Q',u.mem_read(at,8))[0]
    system,services,array,opens=ram,ram+0x1000,ram+0x3000,ram+0x4000
    physical,parent,agent=0x55550000,0x66660000,0x88880000
    put(system+0x60,services)
    for off in (0x138,0x128,0x48):put(services+off,stubs+off)
    sp=ram+0x18008;put(sp,stubs+0x800)
    present=case not in ('absent','absent-with-get','stale-owner-after')
    for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,system),(UC_X86_REG_RDX,physical),(UC_X86_REG_R8,agent),(UC_X86_REG_R9,int(present))]:u.reg_write(reg,value)
    def hook(engine,address,size,user):
        if image<=address<image+0x20000:return
        off=address-stubs;rcx,rdx,r8,r9=[engine.reg_read(r) for r in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9)]
        status=0
        if off==0x138:
            handles=[parent,physical] if nv else [parent if case=='wrong-handle' else physical]
            if case=='two-handles':handles.append(parent)
            for i,h in enumerate(handles):put(array+i*8,h)
            put(r9,len(handles));put(get(engine.reg_read(UC_X86_REG_RSP)+0x28),array)
        elif off==0x128:
            records=[];guid=bytes(engine.mem_read(rdx,4))
            if nv:
                if guid==bytes.fromhex('916e5709') and rcx==parent:
                    if case!='missing-child':records=[(agent,physical+8 if case=='wrong-child' else physical,8,2 if case=='wrong-count' else 1)]
                    if case=='duplicate-child':records*=2
                elif guid==bytes.fromhex('00b2f54c') and rcx==parent:
                    records=[(agent+8 if case=='wrong-parent-owner' else agent,parent,16,1)]
            elif case not in ('absent','absent-with-get'):
                records=[(agent+8 if case=='wrong-agent' else agent,physical,16,2 if case=='wrong-count' else 1)]
            elif case=='absent-with-get':records=[(agent+8,0,1,1)]
            for i,rec in enumerate(records):engine.mem_write(opens+24*i,struct.pack('<QQII',*rec))
            put(r8,opens if records else 0);put(r9,257 if case=='too-many-opens' else len(records))
            if case=='open-error':status=0x8000000000000003
        elif off==0x48:
            if rcx not in (array,opens):raise AssertionError('Unexpected free')
        else:raise AssertionError('Unexpected control transfer')
        rsp=engine.reg_read(UC_X86_REG_RSP);engine.reg_write(UC_X86_REG_RAX,status)
        engine.reg_write(UC_X86_REG_RIP,get(rsp));engine.reg_write(UC_X86_REG_RSP,rsp+8)
    u.hook_add(UC_HOOK_CODE,hook);u.emu_start(image+entry,stubs+0x800,count=20000)
    status=u.reg_read(UC_X86_REG_RAX)
    if (status==0)!=(case in ('success','absent','absent-with-get')) or u.reg_read(UC_X86_REG_RSP)!=sp+8:raise AssertionError(f'Unexpected result {case}: {status:x}')
    rows.append({'case':case,'status':hex(status)})
print(json.dumps({'helper':'nvidia' if nv else 'edid','cases':rows,'hardware_accessed':False,'native_firmware_executed':False},indent=2))
