"""Compiled cold probe with mocked PCI/MMIO services; PROM input stays private.
No device access, native firmware execution, or proof of live recovery.
"""
import json
import struct
import sys
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RSP, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RAX, UC_X86_REG_RIP

data=Path(sys.argv[1]).read_bytes();prefix=Path(sys.argv[2]).read_bytes()[:1048576] if '--full-prom' in sys.argv else Path(sys.argv[2]).read_bytes()[:512]
pe=struct.unpack_from('<I',data,60)[0];opt=pe+24;entry=struct.unpack_from('<I',data,opt+16)[0];table=opt+struct.unpack_from('<H',data,pe+20)[0]
offsets={0x118128,0x118234,0x110100,0x1fa828,0x823804,0x82381c,0x823820,0x1183a4}
cases=['success','volatile-ss0','claim-failure','initial-command-set','forbidden-saved-attrs','bad-bar-size','enable-failure','enabled-attrs-bme','bad-chip','bad-register','read-failure','prefix-mismatch','disable-failure','restore-mismatch','close-failure','stale-owner','log-failure']
admission='--admission' in sys.argv
fixture_cfg=None
if admission:
    capture=Path(sys.argv[sys.argv.index('--capture')+1]).read_text()
    config_line=next(line for line in capture.splitlines() if line.startswith('cfg dwords='))
    fixture_cfg=[int(value,16) for value in config_line.split('=',1)[1].split()]
dma='--dma' in sys.argv
full='--full-prom' in sys.argv
if full:cases=['success','prefix-mismatch','late-prom-mismatch']
if dma:cases=['success','allocate-failure','map-failure','short-map','high-map','mapped-bme','unmap-failure','free-failure']
if admission:cases=['success','stale-ss0','admission-config-failure','admission-location-failure','wrong-msi-subsystem','admission-cap-invalid']
rows=[]
for case in cases:
    u=Uc(UC_ARCH_X86,UC_MODE_64);image,ram,stubs=0x10000000,0x20000000,0x30000000
    for at,size in [(image,0x200000),(ram,0x20000),(stubs,0x2000)]:u.mem_map(at,size)
    for i in range(struct.unpack_from('<H',data,pe+6)[0]):
        rva,size,raw=struct.unpack_from('<III',data,table+40*i+12)
        if size:u.mem_write(image+rva,data[raw:raw+size])
    def put(at,value):u.mem_write(at,struct.pack('<Q',value))
    def get(at):return struct.unpack('<Q',u.mem_read(at,8))[0]
    system,services,pci,bar,opens=ram,ram+0x1000,ram+0x3000,ram+0x5000,ram+0x6000
    put(system+0x60,services)
    for at in (0x118,0x120,0x128,0x48):put(services+at,stubs+at)
    for at,stub in [(0x10,0x500),(0x30,0x530),(0x78,0x578),(0x80,0x580)]:put(pci+at,stubs+stub)
    if dma:
        for at in (0x48,0x50,0x58,0x60,0x70):put(pci+at,stubs+0x600+at)
    sp=ram+0x18008;put(sp,stubs+0x1000)
    for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,system),(UC_X86_REG_RDX,0),(UC_X86_REG_R8,0),(UC_X86_REG_R9,stubs+0x200)]:u.reg_write(reg,value)
    state={'enabled':False,'disabled':False,'claimed':False};reads=[];calls=[];events=[];dma_state={'allocated':False,'mapped':False}
    def hook(engine,address,size,user):
        if image<=address<image+0x200000:return
        off=address-stubs;rcx,rdx,r8,r9=[engine.reg_read(r) for r in (UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9)]
        rsp=engine.reg_read(UC_X86_REG_RSP);status=0;calls.append(hex(off))
        if off==0x118:
            if r9!=0x88880000 or get(rsp+0x30)!=0x20:raise AssertionError('Wrong exclusive claim')
            if case=='claim-failure':status=0x8000000000000003
            else:put(r8,pci);state['claimed']=True
        elif off==0x120:
            if state['enabled']:raise AssertionError('Closed before normal decode restoration')
            if case=='close-failure':status=0x8000000000000003
            else:state['claimed']=False
        elif off==0x128:
            if case=='stale-owner':
                engine.mem_write(opens,struct.pack('<QQII',0x88880000,0,0x20,1));put(r8,opens);put(r9,1)
            else:put(r8,0);put(r9,0)
        elif off==0x48:
            if rcx not in (bar,opens):raise AssertionError('Unexpected pool free')
        elif off==0x658:
            assert state['enabled'] and state['claimed'] and rdx==0 and r8==4 and r9==20576 and get(rsp+0x30)==0
            if case=='allocate-failure':status=0x8000000000000009
            else:put(get(rsp+0x28),ram+0x8000);dma_state['allocated']=True
        elif off==0x648:
            assert dma_state['allocated'] and rdx==2 and r8==ram+0x8000 and get(r9)==20576*4096
            if case=='map-failure':status=0x8000000000000003
            else:
                if case=='short-map':put(r9,4096)
                put(get(rsp+0x28),0x100000000 if case=='high-map' else 0x40000000)
                put(get(rsp+0x30),0x76540000);dma_state['mapped']=True
        elif off==0x650:
            assert dma_state['mapped'] and rdx==0x76540000
            if case=='unmap-failure':status=0x8000000000000007
            else:dma_state['mapped']=False
        elif off==0x660:
            assert dma_state['allocated'] and not dma_state['mapped'] and rdx==20576 and r8==ram+0x8000
            if case=='free-failure':status=0x8000000000000007
            else:dma_state['allocated']=False
        elif off==0x670:
            if case=='admission-location-failure':status=0x8000000000000007
            else:put(rdx,0);put(r8,1);put(r9,0);put(get(rsp+0x28),0)
        elif off==0x530:
            if admission and r9==64:
                cfg=fixture_cfg.copy();cfg[1]=(cfg[1]&0xffff0000)|2
                if case=='wrong-msi-subsystem':cfg[11]=0x33873842
                if case=='admission-cap-invalid':cfg[13]=0x61
                if case=='admission-config-failure':status=0x8000000000000007
                else:engine.mem_write(get(rsp+0x28),struct.pack('<64I',*cfg))
            elif rdx!=2 or r8!=0 or r9!=16:raise AssertionError('Unexpected config read')
            if not (admission and r9==64):
                cfg=[0]*16;cfg[0]=0x220410de;cfg[1]=2 if state['enabled'] else 1 if case=='initial-command-set' else 0
                cfg[2]=0x030000a1;cfg[4]=0x91000000 if admission else 0x80000000;cfg[11]=0x38811462
                engine.mem_write(get(rsp+0x28),struct.pack('<16I',*cfg))
        elif off==0x578:
            if rdx==0:
                value=0x200 if state['enabled'] else 0
                if case=='forbidden-saved-attrs' and not state['enabled']:value=0x400
                if case=='enabled-attrs-bme' and state['enabled']:value|=0x400
                if case=='mapped-bme' and dma_state['mapped']:value|=0x400
                if case=='restore-mismatch' and state['disabled']:value=0x80
                put(r9,value)
            elif rdx in (2,3):
                if r8!=0x200:raise AssertionError('Enabled forbidden PCI attribute')
                if (rdx,case) in [(2,'enable-failure'),(3,'disable-failure')]:status=0x8000000000000003
                else:state['enabled']=rdx==2;state['disabled']=rdx==3
            else:raise AssertionError('Unexpected attribute operation')
        elif off==0x580:
            descriptor=bytearray(46);descriptor[0]=0x8a;struct.pack_into('<H',descriptor,1,43)
            struct.pack_into('<Q',descriptor,6,32);struct.pack_into('<Q',descriptor,14,0x91000000 if admission else 0x80000000)
            struct.pack_into('<Q',descriptor,22,0x80ffffff);struct.pack_into('<Q',descriptor,38,0x800000 if case=='bad-bar-size' else 0x1000000)
            engine.mem_write(bar,bytes(descriptor));put(r9,bar)
        elif off==0x500:
            if not state['enabled'] or not state['claimed'] or rdx!=2 or r8!=0 or get(rsp+0x28)!=1:raise AssertionError('MMIO outside enabled exclusive phase')
            reads.append(r9);value=0
            if r9==0:value=0xffffffff if case=='bad-chip' else 0xb72000a1
            elif r9 in offsets:
                value=0xbadf0000 if case=='bad-register' else 0
                if admission:
                    value={0x118128:0x8b8f,0x118234:0x3ff,0x110100:0x10,0x1fa828:0,0x823804:0xffffff8f,0x82381c:0x70232144,0x823820:7,0x1183a4:0x6000}[r9]
                    if case=='stale-ss0' and r9==0x82381c and len(reads)>262162:value^=0x40000000
                if r9==0x82381c and case=='volatile-ss0':value=len(reads)
            elif 0x300000<=r9<=(0x3ffffc if full else 0x3001fc) and r9%4==0:
                value=struct.unpack_from('<I',prefix,r9-0x300000)[0]
                if case=='prefix-mismatch' and r9==0x300000:value^=1
                if case=='late-prom-mismatch' and r9==0x3ffffc:value^=1
            else:raise AssertionError(f'Unexpected MMIO offset {r9:x}')
            if case=='read-failure':status=0x8000000000000007
            else:engine.mem_write(get(rsp+0x30),struct.pack('<I',value))
        elif off==0x200:
            event=bytes(engine.mem_read(rdx,100)).split(b'\0',1)[0].decode();events.append((event,r8))
            if case=='log-failure' and event=='msi-cold-memory-enable-return':status=0x8000000000000007
        else:raise AssertionError(f'Unexpected service {off:x}')
        engine.reg_write(UC_X86_REG_RAX,status);engine.reg_write(UC_X86_REG_RIP,get(rsp));engine.reg_write(UC_X86_REG_RSP,rsp+8)
    u.hook_add(UC_HOOK_CODE,hook,begin=stubs,end=stubs+0x2000);u.emu_start(image+entry,stubs+0x1000,count=1000000000)
    status=u.reg_read(UC_X86_REG_RAX);success=case in ('success','volatile-ss0')
    if (status==0)!=success or u.reg_read(UC_X86_REG_RSP)!=sp+8:raise AssertionError(f'Wrong result {case}: {status:x}')
    if success and (len(reads)!=(262171 if admission else 262162 if full else 146) or state['enabled'] or state['claimed']):raise AssertionError('Incomplete normal completion')
    if case in ('bad-chip','bad-register','read-failure','prefix-mismatch','late-prom-mismatch','disable-failure','log-failure') and not state['enabled']:raise AssertionError('Unexpected automatic error rollback')
    if dma and success:assert not dma_state['mapped'] and not dma_state['allocated']
    if dma and not success:assert state['enabled'] and state['claimed']
    rows.append({'dma_resources':dma_state,'case':case,'status':hex(status),'mmio_reads':len(reads),'state_at_return':state})
print(json.dumps({'cases':rows,'hardware_accessed':False,'native_firmware_executed':False,'live_recovery_proven':False},indent=2))
