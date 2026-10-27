/* GPL-2.0-only. Real combined lifecycle/decoder engine with RAM-only MMIO. */
#define GU_AD104_DECODE_READ_TEST
#define main ParentMain
#include "test_owner_parent.c"
#undef main
static int BatchFileCalls;
#ifdef GU_AD104_PROM_HEADER_TEST
static int PromFileCalls;
#endif
static EFI_STATUS EFIAPI ReadBar(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_WIDTH width,
                                UINT8 bar,UINT64 offset,UINTN count,VOID *out) {
  (void)io;Check(width==EfiPciIoWidthUint32 && !bar && count==1 && DecodeCalls==1 && Stage==6,
    "MMIO only after explicit decode Enable");
#ifdef GU_AD104_PROM_FULL_TEST
  if(MmioCalls>=174) {
    UINTN n=MmioCalls-174;
    Check(n<262146,"bounded full PROM plus bookends");
    if(!n)PromFileCalls=Writes+Flushes;
    Check(Writes+Flushes==PromFileCalls,"no file callbacks within full PROM reads");
    Check(offset==(n<262144?0x300000+n*4:n==262144?0x300000:0),"contiguous exact 1 MiB window then signature/chip");
    MmioCalls++;UINT32 v=(UINT32)n;
    if(n<128 || n==262144)v=0;
    if(!n || n==262144)v=0xaa55;
    if(n==6)v=0x170;if(n==92)v=0x52494350;if(n==93)v=0x278210de;
    if(n==94)v=0x00180000;if(n==96)v=0x7e;
    if(n==200)v=MAX_UINT32;if(n==201)v=0xbadf5620;
    if(n==262145)v=0x194000a1;
    if(PromFault>=2000 && n==(UINTN)(PromFault-2000))return EFI_DEVICE_ERROR;
    if(PromFault==20 && !n)v=MAX_UINT32;
    if(PromFault==21 && n==20)v^=1;
    if(PromFault==22 && n==262144)v^=1;
    if(PromFault==23 && n==262145)v=0;
    if(PromFault==24 && n==1024)Io.Mem.Read=NULL;
    if(PromFault==25 && n==262145)Config[1]|=4;
    *(UINT32 *)out=v;return EFI_SUCCESS;
  }
#endif
#ifdef GU_AD104_PROM_HEADER_TEST
  if(MmioCalls>=44) {
    UINTN n=MmioCalls-44;Check(n<130,"bounded header and signature/chip bookends");
    if(!n)PromFileCalls=Writes+Flushes;
    Check(Writes+Flushes==PromFileCalls,"no file callbacks within PROM window reads");
    Check(offset==(n<128?0x300000+n*4:n==128?0x300000:0),"only admitted PROM prefix and bookends");
    MmioCalls++;UINT32 v=0;
    if(n==0 || n==128)v=0xaa55;
    UINTN pw=(PromFault==17 || PromFault==18)?122:92;
    if(n==6)v=(UINT32)pw*4;
    if(n==pw)v=0x52494350;
    if(n==pw+1)v=0x278210de;
    if(n==pw+2)v=PromFault==18?0x00190000:0x00180000;
    if(n==pw+4)v=0x7e;
    if(PromFault==16 && n==20)v=MAX_UINT32;
    if(PromFault==16 && n==21)v=0xbadf5620;
    if(n==129)v=0x194000a1;
    if(PromFault>=1000 && n==(UINTN)(PromFault-1000))return EFI_DEVICE_ERROR;
    if(PromFault==1 && !n)v=MAX_UINT32;
    if(PromFault==2 && n==6)v=0xfff0;
    if(PromFault==3 && n==93)v=0;
    if(PromFault==4 && n==94)v=0;
    if(PromFault==5 && n==96)v=0;
    if(PromFault==6 && n==128)v^=1;
    if(PromFault==7 && n==129)v=0;
    if(PromFault==8 && n==64)Io.Mem.Read=NULL;
    if(PromFault==9 && n==129)Config[1]|=4;
    *(UINT32 *)out=v;return EFI_SUCCESS;
  }
#endif
  UINTN index=(UINTN)MmioCalls%22;
  if(!index)BatchFileCalls=Writes+Flushes;
  Check(Writes+Flushes==BatchFileCalls,"no log service callbacks within an MMIO batch");
  Check(offset==DecodeOffsets[index] && offset<=0x1000000-4,"only bounded allowlisted registers");
  MmioCalls++;*(UINT32 *)out=(index==0 || index==21)?0x194000a1U:0;
#ifdef GU_AD104_DELAYED_READ_TEST
  if(OffFault==18 && MmioCalls==36)*(UINT32 *)out=6;
  if(OffFault==19 && MmioCalls==38)*(UINT32 *)out=1;
#endif
  if((DecodeFault>=100 && DecodeFault<122 && MmioCalls==DecodeFault-99) ||
     (DecodeFault>=200 && DecodeFault<222 && MmioCalls==DecodeFault-177))return EFI_DEVICE_ERROR;
  if(DecodeFault==9 && MmioCalls==7)return EFI_DEVICE_ERROR;
  if(DecodeFault==10 && MmioCalls==7)*(UINT32 *)out=0xbadf5620;
  if(DecodeFault==11 && MmioCalls==44)*(UINT32 *)out=1;
  if(DecodeFault==12 && MmioCalls==1)*(UINT32 *)out=0;
  if(DecodeFault==13 && MmioCalls==22)Config[1]|=4;
  if(DecodeFault==18 && MmioCalls==5)Io.Mem.Read=NULL;
  if(DecodeFault==19 && MmioCalls==7)*(UINT32 *)out=MAX_UINT32;
  if(DecodeFault==20 && MmioCalls==23)*(UINT32 *)out=0;
  if(DecodeFault==21 && MmioCalls==44)Config[1]|=4;
  if(DecodeFault==22 && MmioCalls==44)Missing=-1;
  return EFI_SUCCESS;
}
static CAPTURE *DecodeSetup(int fault) {
  CAPTURE *c=ParentSetup(0);DecodeFault=fault;DecodeCalls=MmioCalls=DecodeFlushes=0;
  DecodeAttempted=FALSE;Io.Mem.Read=ReadBar;
#ifdef GU_AD104_DECODE_OFF_TEST
  OffIntentSeen=0;
#ifdef GU_AD104_PROM_HEADER_TEST
  PromIntentSeen=PromOutputSeen=0;
#ifdef GU_AD104_FWSEC_AUDIT_TEST
  AuditSeen=0;
#endif
#endif
#endif
  return c;
}
#ifdef GU_AD104_PROM_FULL_TEST
static EFI_FILE_PROTOCOL FullRoot,FullFile,FullWitness;
static UINT8 SavedProm[0x100000];static UINTN FilePosition;
static VOID *FullAllocation;static EFI_ALLOCATE_POOL SavedAllocate;static EFI_FREE_POOL SavedFree;
static EFI_STATUS EFIAPI FullAllocate(EFI_MEMORY_TYPE type,UINTN n,VOID **out) {
  if(n==0x200000){if(PromFault==52){*out=NULL;return EFI_SUCCESS;}if(PromFault==26)return EFI_OUT_OF_RESOURCES;EFI_STATUS s=EFI_SUCCESS;*out=calloc(1,n);if(!*out)s=EFI_OUT_OF_RESOURCES;FullAllocation=*out;if(PromFault==38)Config[1]|=4;return s;}
  return SavedAllocate?SavedAllocate(type,n,out):EFI_UNSUPPORTED;
}
static EFI_STATUS EFIAPI FullFree(VOID *p) {
  BOOLEAN full=p==FullAllocation;EFI_STATUS s=SavedFree(p);
  if(full){FullAllocation=NULL;if(PromFault==41)Config[1]|=4;if(PromFault==36)return EFI_DEVICE_ERROR;}return s;
}
static EFI_STATUS EFIAPI FullWrite(EFI_FILE_PROTOCOL *f,UINTN *n,VOID *p) {
  Check(f==&FullFile && *n==0x100000,"one exact PROM file write");if(PromFault==54)((UINT8 *)p)[512]^=1;memcpy(SavedProm,p,*n);
  if(PromFault==29)(*n)--;if(PromFault==42)FullFile.Read=NULL;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI FullRead(EFI_FILE_PROTOCOL *f,UINTN *n,VOID *p) {
  Check(f==&FullFile,"read back same PROM file");
  if(*n==1){*n=PromFault==33?1:0;return EFI_SUCCESS;}
  Check(*n==0x100000 && !FilePosition,"exact readback after seek");memcpy(p,SavedProm,*n);FilePosition=*n;
  if(PromFault==32)(*n)--;if(PromFault==34)((UINT8 *)p)[512]^=1;if(PromFault==40)Config[1]|=4;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI FullSeek(EFI_FILE_PROTOCOL *f,UINT64 n){Check(f==&FullFile && !n,"seek to zero only");FilePosition=0;return PromFault==31?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI FullFlush(EFI_FILE_PROTOCOL *f){Check(f==&FullFile,"flush PROM only");return PromFault==30?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI FullClose(EFI_FILE_PROTOCOL *f){Check(f==&FullFile,"never close root/log/witness");return PromFault==35?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI FullOpen(EFI_FILE_PROTOCOL *f,EFI_FILE_PROTOCOL **out,CHAR16 *name,UINT64 mode,UINT64 attr) {
  Check(f==&FullRoot && name && !attr,"only borrowed capture root");*out=NULL;
  if(mode==EFI_FILE_MODE_READ){if(PromFault==27){*out=&FullFile;return EFI_SUCCESS;}return EFI_NOT_FOUND;}
  Check(mode==(EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE),"only new capture file");
  *out=PromFault==28?&FullRoot:&FullFile;
  if(PromFault==43)*out=&File;if(PromFault==44)*out=&FullWitness;
  if(PromFault==47)return EFI_DEVICE_ERROR;
  if(PromFault==48)FullFile.Read=NULL;if(PromFault==49)FullFile.Flush=NULL;if(PromFault==50)FullFile.Close=NULL;
  if(PromFault==39)Config[1]|=4;return EFI_SUCCESS;
}
static CAPTURE *FullSetup(int fault) {
  CAPTURE *c=DecodeSetup(0);OffCalls=OffFault=0;DecodeOffAttempted=PromHeaderAttempted=PromFullAttempted=FALSE;PromFault=fault;
  PromPrefixGpu=NULL;PromPrefixIo=NULL;FullAllocation=NULL;FilePosition=0;
  memset(&FullRoot,0,sizeof(FullRoot));memset(&FullFile,0,sizeof(FullFile));memset(&FullWitness,0,sizeof(FullWitness));
  FullRoot.Open=FullOpen;FullFile.Write=FullWrite;FullFile.Read=FullRead;FullFile.SetPosition=FullSeek;FullFile.Flush=FullFlush;FullFile.Close=FullClose;
  c->DumpRoot=&FullRoot;c->Witness=&FullWitness;SavedAllocate=Bs.AllocatePool;SavedFree=Bs.FreePool;Bs.AllocatePool=FullAllocate;Bs.FreePool=FullFree;return c;
}
int main(void) {
  CAPTURE *c=FullSetup(0);Check(EdRun(c,(VOID *)1,&Io,Pins)==EFI_SUCCESS && OffCalls==1 && MmioCalls==262320 && !FullAllocation,"full capture/file readback then recovery");
  for(int f=20;f<=
#ifdef GU_AD104_FWSEC_AUDIT_TEST
  57
#else
  54
#endif
  ;f++) {
    if(f==45 || f==46 || f==51 || f==53)continue;
    c=FullSetup(f);Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !OffCalls && !FullAllocation,"full read/file/cleanup/state faults block handoff");
  }
  int points[]={0,1,127,128,1023,1024,131072,262142,262143,262144,262145};
  for(UINTN j=0;j<sizeof(points)/sizeof(points[0]);j++) {
    c=FullSetup(2000+points[j]);Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !OffCalls && MmioCalls==175+points[j] && !FullAllocation,"selected boundary transport errors stop without retry");
  }
  printf("PASS full PROM capture: %d checks, RAM-only mocks\n",Checks);return 0;
}
#elif defined(GU_AD104_PROM_HEADER_TEST)
int main(void) {
  CAPTURE *c=DecodeSetup(0);DecodeOffAttempted=PromHeaderAttempted=FALSE;OffFault=OffCalls=PromFault=0;
  Check(EdRun(c,(VOID *)1,&Io,Pins)==EFI_SUCCESS && MmioCalls==174 && OffCalls==1,"bounded PROM header then verified recovery");
  Check(PromHeader(c,(VOID *)1,&Io,Pins,NULL)==EFI_ALREADY_STARTED,"no header retry");
  for(int f=1;f<=18;f++) {
    c=DecodeSetup(0);DecodeOffAttempted=PromHeaderAttempted=FALSE;OffCalls=0;PromFault=f;
    EFI_STATUS s=EdRun(c,(VOID *)1,&Io,Pins);
    if(f==16 || f==17)Check(s==EFI_SUCCESS && OffCalls==1,"literal payload sentinels and max legal PCIR header are valid");
    else Check(s!=EFI_SUCCESS && !OffCalls,"header/admission/output faults block handoff");
    if(f>=10 && f<=13)Check(MmioCalls==44,"intent flush admission drift prevents every PROM read");
  }
  for(int n=0;n<130;n++) {
    c=DecodeSetup(0);DecodeOffAttempted=PromHeaderAttempted=FALSE;OffCalls=0;PromFault=1000+n;
    Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !OffCalls && MmioCalls==45+n,"every PROM/bookend transport error stops remaining reads");
  }
  printf("PASS bounded PROM header: %d checks, RAM-only mocks\n",Checks);return 0;
}
#elif defined(GU_AD104_DECODE_OFF_TEST)
int main(void) {
  CAPTURE *c=DecodeSetup(0);DecodeOffAttempted=FALSE;OffFault=OffCalls=0;
  EFI_STATUS run=EdRun(c,(VOID *)1,&Io,Pins);
  Check(run==EFI_SUCCESS && OffCalls==1 && MmioCalls==44,"capture then one decode off qualifies Windows");
  Check(CurrentAttributes==0 && !(Config[1]&7),"exact post-parent decode/BME state restored");
  Check(DecodeOff(c,(VOID *)1,&Io,Pins,NULL,NULL)==EFI_ALREADY_STARTED && OffCalls==1,"no disable retry");
  for(int f=1;f<=
#ifdef GU_AD104_DELAYED_READ_TEST
  19
#else
  13
#endif
  ;f++) {
    c=DecodeSetup(0);DecodeOffAttempted=FALSE;OffFault=f;OffCalls=0;
    Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && OffCalls==((f==6 || f==9 || f==10 || f>=11)?0:1) && MmioCalls==((f>=14 && f<=17)?22:44),"disable error/partial/config/log drift blocks Windows without more MMIO");
  }
  c=DecodeSetup(10);DecodeOffAttempted=FALSE;OffFault=OffCalls=0;
  Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !OffCalls,"failed capture prevents disable");
  printf("PASS capture then decode off: %d checks, RAM-only mocks\n",Checks);return 0;
}
#else
int main(void) {
  CAPTURE *c=DecodeSetup(0);
  Check(EdRun(c,(VOID *)1,&Io,Pins)==EFI_SUCCESS && DecodeCalls==1 && MmioCalls==44,
    "all release stages plus limited decode and two register batches qualify handoff");
  Check(CurrentAttributes==0x300 && (Config[1]&7)==3,"BME/VGA remain off");
  Check(DecodeStep(c,(VOID *)1,&Io,Pins,NULL)==EFI_ALREADY_STARTED && DecodeCalls==1,"no second Enable");
  for(int f=1;f<=25;f++) {
    c=DecodeSetup(f);
    Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS,"decode/read/log/state/input faults block handoff");
    Check(DecodeCalls==(f==14?0:1),"failed decode intent prevents Enable");
    if(f==16 || f==23 || f==24 || f==25)Check(MmioCalls==22,"batch flush failure or state drift prevents second MMIO batch");
    if(f<=8 || f==14)Check(!MmioCalls,"failed or mismatching Enable performs zero MMIO");
  }
  for(int batch=0;batch<2;batch++)for(int i=0;i<22;i++) {
    c=DecodeSetup((batch?200:100)+i);
    Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS,"each individual read failure blocks handoff");
    Check(MmioCalls==batch*22+i+1,"read failure prevents remaining reads");
  }
  c=DecodeSetup(0);ParentFault=2;
  Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !DecodeCalls && !MmioCalls,"failed parent prevents decode and MMIO");
  printf("PASS limited decode and registers: %d checks, RAM-only mocks\n",Checks);return 0;
}

#endif
