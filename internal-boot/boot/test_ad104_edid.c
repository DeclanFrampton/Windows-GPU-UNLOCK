/* GPL-2.0-only. Executes only RAM mocks, never firmware code. */
#define main PreflightMain
#include "test_ad104_preflight.c"
#undef main
#include <IndustryStandard/Acpi.h>
#include "diagnostic.h"
static int Writes,Flushes,Calls,Stage,KeyPhase,Reads,EdFault,Collections;
static EFI_PCI_IO_PROTOCOL Io;
static EFI_FILE_PROTOCOL File;
static EFI_SIMPLE_TEXT_INPUT_PROTOCOL Input;
static EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL Output;
static UINT32 Config[64];
VOID Text(CAPTURE *c,const char *s){while(*s && c->Used<sizeof(c->Buffer))c->Buffer[c->Used++]=*s++;}
VOID Hex(CAPTURE *c,UINT64 v,UINTN n){(void)v;(void)n;Text(c,"x");}
VOID End(CAPTURE *c){Text(c,"\n");}
#include "ad104-edid.h"
static EFI_STATUS EFIAPI EdHandle(EFI_HANDLE h,EFI_GUID *g,VOID **out) {
  if(h==(VOID *)1 && PfEqual(g,&PciGuidL,sizeof(*g))){*out=&Io;return EFI_SUCCESS;}
  return HandleMock(h,g,out);
}
static EFI_STATUS EFIAPI ReadConfig(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_WIDTH w,UINT32 off,UINTN count,VOID *p) {
  (void)io;(void)w;Collections++;memcpy(p,(UINT8 *)Config+off,count*4);return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Location(EFI_PCI_IO_PROTOCOL *io,UINTN *a,UINTN *b,UINTN *c,UINTN *d) {
  (void)io;*a=0;*b=11;*c=*d=0;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Bar(EFI_PCI_IO_PROTOCOL *io,UINT8 index,UINT64 *support,VOID **out) {
  (void)io;(void)index;UINT8 *b=calloc(1,sizeof(EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR)+2);
  EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *d=(VOID *)b;
  d->Desc=ACPI_ADDRESS_SPACE_DESCRIPTOR;d->Len=sizeof(*d)-3;
  d->AddrSpaceGranularity=32;d->AddrRangeMin=0xfb000000;d->AddrRangeMax=0xfbffffff;d->AddrLen=0x1000000;
  b[sizeof(*d)]=ACPI_END_TAG_DESCRIPTOR;*out=b;*support=0;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Attributes(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_ATTRIBUTE_OPERATION op,UINT64 value,UINT64 *out) {
  (void)io;(void)value;
  if(op==EfiPciIoAttributeOperationGet){*out=0x718;return EFI_SUCCESS;}
  if(op==EfiPciIoAttributeOperationSupported){*out=0x1b77b;return EFI_SUCCESS;}
  Check(0,"attribute write forbidden");return EFI_UNSUPPORTED;
}
static EFI_STATUS EFIAPI Write(EFI_FILE_PROTOCOL *f,UINTN *n,VOID *p) {
  (void)f;(void)n;(void)p;Writes++;return EdFault==1 || (EdFault==15 && Stage)?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI FlushFile(EFI_FILE_PROTOCOL *f){(void)f;Flushes++;return EdFault==2 || (EdFault==16 && Stage)?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI Reset(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *i,BOOLEAN b){(void)i;(void)b;Check(0,"no reset");return EFI_UNSUPPORTED;}
static EFI_STATUS EFIAPI ReadKey(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *i,EFI_INPUT_KEY *k) {
  (void)i;Reads++;
  if(!KeyPhase || EdFault==3 || (EdFault==8 && KeyPhase==2))return EFI_NOT_READY;
  k->ScanCode=0;k->UnicodeChar=(CHAR16)(KeyPhase==1?'E':'V');
  if(EdFault==4)k->UnicodeChar='x';
  if(EdFault==18 && KeyPhase==2)Config[1]=3;
  KeyPhase=0;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Print(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *o,CHAR16 *s) {
  (void)o;(void)s;KeyPhase=Stage?2:1;
  if(EdFault==10 && !Stage)Config[3]++;
  return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Stall(UINTN us){(void)us;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Disconnect(EFI_HANDLE child,EFI_HANDLE agent,EFI_HANDLE deeper) {
  Check(child==(VOID *)2 && agent==(VOID *)10 && !deeper,"only exact EDID binding/child");
  Check(Flushes>=2 && Writes>=2 && EdAttempted,"durable intent and attempted before callback");
  Calls++;Stage=1;
  Missing=5;Data[0][0x546a]=0;
  if(EdFault==11 || EdFault==12){Io.GetBarAttributes=NULL;return EdFault==12?EFI_DEVICE_ERROR:EFI_SUCCESS;}
  if(EdFault==13 || EdFault==14){Io.Pci.Read=NULL;return EdFault==14?EFI_DEVICE_ERROR:EFI_SUCCESS;}
  if(EdFault==5)return EFI_DEVICE_ERROR;
  if(EdFault==6)Missing=6;
  if(EdFault==7)Config[1]=3;
  if(EdFault==9)Data[0][0x546a]=1;
  if(EdFault==17)Missing=-1;
  return EFI_SUCCESS;
}
static CAPTURE *EdSetup(int fault) {
  Setup(0,-1);EdFault=fault;EdAttempted=FALSE;Writes=Flushes=Calls=Stage=KeyPhase=Reads=Collections=0;
  Bs.HandleProtocol=EdHandle;Bs.DisconnectController=Disconnect;Bs.Stall=Stall;
  memset(&Io,0,sizeof(Io));Io.Pci.Read=ReadConfig;Io.GetLocation=Location;Io.GetBarAttributes=Bar;Io.Attributes=Attributes;
  memset(Config,0,sizeof(Config));Config[0]=0x278210de;Config[1]=0x100007;Config[2]=0x030000a1;
  Config[4]=0xfb000000;Config[11]=0x51321462;
  memset(&File,0,sizeof(File));File.Write=Write;File.Flush=FlushFile;
  memset(&Input,0,sizeof(Input));Input.Reset=Reset;Input.ReadKeyStroke=ReadKey;Input.WaitForKey=(VOID *)1;
  memset(&Output,0,sizeof(Output));Output.OutputString=Print;
  T.ConIn=&Input;T.ConOut=T.StdErr=&Output;
  Data[0][0x546a]=1;*(UINT64 *)(Data[0]+0x5530)=1;*(UINT64 *)(Data[0]+0x5550)=1;
  static CAPTURE c;memset(&c,0,sizeof(c));c.Table=&T;c.File=&File;c.Io=EFI_SUCCESS;return &c;
}
int main(void) {
  CAPTURE *c=EdSetup(0);
  Check(EdRun(c,(VOID *)1,&Io,Pins)==EFI_SUCCESS,"one exact transition permits Windows consideration");
  Check(Calls==1 && Stage==1,"single invocation");
  Check(EdRun(c,(VOID *)1,&Io,Pins)==EFI_ALREADY_STARTED && Calls==1,"retry forbidden");
  for(int f=1;f<=18;f++) {
    c=EdSetup(f);Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS,"logging/input/callback/post failure blocks Windows");
    Check(Calls==(f<=4 || f==10?0:1),"precondition failures never invoke callback");
    if(f>=5 && f!=10)Check(Collections>=(f==13 || f==14?3:5),"callback errors and post failures still run independent collections");
  }
  c=EdSetup(0);Config[0]^=1;Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !Calls,"wrong GPU rejected");
  c=EdSetup(0);Data[1][0x100]^=1;Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !Calls,"wrong code rejected");
  c=EdSetup(0);Missing=7;Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !Calls,"missing pre-edge rejected");
  c=EdSetup(0);T.ConIn=NULL;Check(EdRun(c,(VOID *)1,&Io,Pins)!=EFI_SUCCESS && !Calls,"no input rejected");
  printf("PASS AD104 EDID lifecycle: %d checks, RAM-only mocks\n",Checks);return 0;
}
