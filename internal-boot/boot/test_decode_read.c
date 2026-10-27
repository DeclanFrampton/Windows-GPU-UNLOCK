/* GPL-2.0-only. Real combined lifecycle/decoder engine with RAM-only MMIO. */
#define GU_AD104_DECODE_READ_TEST
#define main ParentMain
#include "test_owner_parent.c"
#undef main
static int BatchFileCalls;
static EFI_STATUS EFIAPI ReadBar(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_WIDTH width,
                                UINT8 bar,UINT64 offset,UINTN count,VOID *out) {
  (void)io;Check(width==EfiPciIoWidthUint32 && !bar && count==1 && DecodeCalls==1 && Stage==6,
    "MMIO only after explicit decode Enable");
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
#endif
  return c;
}
#ifdef GU_AD104_DECODE_OFF_TEST
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
