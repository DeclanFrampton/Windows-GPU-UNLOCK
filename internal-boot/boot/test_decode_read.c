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
  DecodeAttempted=FALSE;Io.Mem.Read=ReadBar;return c;
}
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
