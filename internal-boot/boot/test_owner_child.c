/* GPL-2.0-only. Real four-stage engine and graph with synthetic RAM services. */
#define GU_AD104_TEXT_TEST
#define GU_AD104_GOP_TEST
#define GU_AD104_CONSUMERS_TEST
#define GU_AD104_OWNER_CHILD_TEST
#define main OriginalMain
#include "test_ad104_edid.c"
#undef main
static int OwnerFault,OwnerCalls,AfterFreeReads,OwnerFlushes;
static EFI_STATUS EFIAPI OwnerStop(EFI_DRIVER_BINDING_PROTOCOL *d,EFI_HANDLE gpu,UINTN n,EFI_HANDLE *child) {
  Check(d==&Drivers[3] && gpu==(VOID *)1 && n==1 && child && *child==(VOID *)2,"direct one-child ABI only, never zero-child Stop");
  Check(Calls==3 && OwnerChildAttempted && GuTextOutputDisabled,"prior stages and one-shot intent");
  OwnerCalls++;
  if(OwnerFault==1)return EFI_DEVICE_ERROR;
  Stage=4;HideChild=OwnerFault==3?0:1;FifthMissing=OwnerFault==4?-1:1;
  if(OwnerFault==5)Missing=0;
  if(OwnerFault==6)Config[1]=0;
  if(OwnerFault==7)*(UINT64 *)(Data[0]+0x5530)=0;
  if(OwnerFault==8)Input.WaitForKey=(VOID *)2;
  return OwnerFault==2?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI OwnerHandle(EFI_HANDLE h,EFI_GUID *g,VOID **out) {
  if(Stage==4 && h==(VOID *)2){AfterFreeReads++;Check(0,"no protocol access on freed child");}
  return EdHandle(h,g,out);
}
static EFI_STATUS EFIAPI OwnerFlush(EFI_FILE_PROTOCOL *f) {
  if(Stage==3 && ++OwnerFlushes==2) {
    if(OwnerFault==9)return EFI_DEVICE_ERROR;
    if(OwnerFault==13)Drivers[3].Stop=(VOID *)((UINTN)OwnerStop+1);
  }
  if(Stage==4 && OwnerFault==12)return EFI_DEVICE_ERROR;
  return FlushFile(f);
}
static EFI_STATUS EFIAPI OwnerKey(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *i,EFI_INPUT_KEY *k) {
  EFI_STATUS s=ReadKey(i,k);
  if(s==EFI_SUCCESS && Stage==4) {
    if(OwnerFault==10)Config[1]=3;
    if(OwnerFault==11)k->UnicodeChar='x';
  }
  return s;
}
static CAPTURE *OwnerSetup(int fault) {
  CAPTURE *c=EdSetup(0);OwnerFault=fault;OwnerCalls=AfterFreeReads=OwnerFlushes=0;OwnerChildAttempted=FALSE;
  /* Pin an actual callable mock as this synthetic loaded image's Stop entry. */
  Images[3].ImageBase=(VOID *)(UINTN)OwnerStop;Pins[3].Code=0;Pins[3].Bytes=8;Pins[3].Stop=0;
  UINT8 digest[32];GuSha256((VOID *)(UINTN)OwnerStop,8,digest);
  for(UINTN i=0;i<32;i++){Hashes[3][i*2]="0123456789abcdef"[digest[i]>>4];Hashes[3][i*2+1]="0123456789abcdef"[digest[i]&15];}
  Drivers[3].Stop=OwnerStop;Drivers[4].Stop=(VOID *)((UINTN)OwnerStop+0x2b38);
  Bs.HandleProtocol=OwnerHandle;File.Flush=OwnerFlush;Input.ReadKeyStroke=OwnerKey;return c;
}
int main(void) {
  CAPTURE *c=OwnerSetup(0);
  Check(EdRun(c,(VOID *)1,&Io,Pins)==EFI_SUCCESS && OwnerCalls==1 && !AfterFreeReads,"four-stage quiet handoff qualifies");
  Check(OwnerChildStep(c,(VOID *)1,&Io,Pins,NULL)==EFI_ALREADY_STARTED && OwnerCalls==1,"direct stop retry refused");
  for(int f=1;f<=13;f++) {
    c=OwnerSetup(f);
    Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS,"partial callback, freed handle, edges, PCI, input, logging fail closed");
    Check(OwnerCalls==(f==9 || f==13?0:1),"intent flush failure prevents direct callback");
    Check(!AfterFreeReads,"no freed child protocol queries even after errors");
  }
  c=OwnerSetup(0);GopFault=3;
  Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !OwnerCalls,"GOP failure prevents owner callback");
  c=OwnerSetup(0);ConsumerFault=2;
  Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !OwnerCalls,"EDID failure prevents owner callback");
  printf("PASS direct owner child: %d checks, RAM-only mocks\n",Checks);return 0;
}
