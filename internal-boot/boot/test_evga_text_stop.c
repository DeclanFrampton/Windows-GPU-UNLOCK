/* GPL-2.0-only. Host mocks: never execute captured firmware or access a GPU. */
#include "evga-text-stop.c"
static EFI_BOOT_SERVICES Bs;
static EFI_SYSTEM_TABLE Table;
static EFI_SIMPLE_TEXT_INPUT_PROTOCOL Input;
static EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL Output;
static EFI_GRAPHICS_OUTPUT_PROTOCOL Graphics[2];
static EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE Modes[2];
static EFI_DRIVER_BINDING_PROTOCOL Drivers[3];
static EFI_LOADED_IMAGE_PROTOCOL Images[3];
static EFI_PCI_IO_PROTOCOL PciIo;
static EFI_FILE_PROTOCOL Root,Marker;
static UINTN Keys,Calls,Records;
static BOOLEAN Removed,MarkerExists,BadHash,BadPost,FailRecord,FailStop,BadInventory,ExtraOwner;
static BOOLEAN Cancel,Timeout,ShortWrite,FlushFail;
static UINTN InterfaceFailure;
static EFI_HANDLE H(UINTN n){return (EFI_HANDLE)n;}
BOOLEAN GuHashMatches(const VOID *data,UINTN n,const char *hash){return data && n && hash && !BadHash;}
static EFI_STATUS EFIAPI Free(VOID *p){return p?EFI_SUCCESS:EFI_INVALID_PARAMETER;}
static EFI_STATUS EFIAPI Stall(UINTN n){(void)n;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI SayMock(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *p,CHAR16 *s){(void)p;(void)s;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI ReadKey(EFI_SIMPLE_TEXT_INPUT_PROTOCOL *p,EFI_INPUT_KEY *k){
  (void)p;if(Keys++==0 || Timeout)return EFI_NOT_READY;k->UnicodeChar=Cancel?0:'G';k->ScanCode=Cancel?SCAN_ESC:0;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI ReadPci(EFI_PCI_IO_PROTOCOL *p,EFI_PCI_IO_PROTOCOL_WIDTH w,UINT32 off,UINTN n,VOID *v){
  (void)p;(void)w;if(off || n!=16)return EFI_INVALID_PARAMETER;
  UINT32 *cfg=v;for(UINTN i=0;i<n;i++)cfg[i]=0;
  cfg[0]=BadInventory?0x123410deU:0x220410deU;cfg[2]=0x03000000U;cfg[11]=0x33873842U;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Locate(EFI_LOCATE_SEARCH_TYPE type,EFI_GUID *guid,VOID *key,UINTN *n,EFI_HANDLE **out){
  (void)type;(void)key;static EFI_HANDLE g[2],p[1];g[0]=H(1);g[1]=H(2);p[0]=H(4);
  if(guid==&Gop){*n=2;*out=g;return EFI_SUCCESS;}
  if(guid==&Pci){*n=1;*out=p;return EFI_SUCCESS;}return EFI_UNSUPPORTED;
}
static EFI_STATUS EFIAPI Handle(EFI_HANDLE h,EFI_GUID *guid,VOID **out){
  *out=NULL;
  if(guid==&Text && ((InterfaceFailure==1 && h==H(2)) || (InterfaceFailure==2 && h==H(3))))return EFI_NOT_FOUND;
  if(guid==&Gop && h==H(3) && InterfaceFailure==3)return EFI_NOT_FOUND;
  if(guid==&Gop && h==H(3) && InterfaceFailure==4){*out=&Graphics[0];return EFI_SUCCESS;}
  if(guid==&Gop && (h==H(1)||h==H(2))){*out=&Graphics[(UINTN)h-1];return EFI_SUCCESS;}
  if(guid==&Path && h==H(1)){*out=&Output;return EFI_SUCCESS;}
  if(guid==&Text && (h==H(2)||h==H(3))){*out=&Output;return EFI_SUCCESS;}
  if(guid==&Binding && (UINTN)h>=10 && (UINTN)h<=12){*out=&Drivers[(UINTN)h-10];return EFI_SUCCESS;}
  if(guid==&Loaded && (UINTN)h>=10 && (UINTN)h<=12){*out=&Images[(UINTN)h-10];return EFI_SUCCESS;}
  if(guid==&Pci && h==H(4)){*out=&PciIo;return EFI_SUCCESS;}return EFI_UNSUPPORTED;
}
static EFI_STATUS EFIAPI ProtocolList(EFI_HANDLE h,EFI_GUID ***out,UINTN *n){
  static EFI_GUID *list[1];if(h!=H(3))return EFI_UNSUPPORTED;
  list[0]=&Text;*out=list;*n=1;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Opens(EFI_HANDLE source,EFI_GUID *guid,EFI_OPEN_PROTOCOL_INFORMATION_ENTRY **out,UINTN *n){
  static EFI_OPEN_PROTOCOL_INFORMATION_ENTRY e[3];*out=e;*n=0;EFI_HANDLE agent=NULL,child=NULL;
  if(source==H(1)&&guid==&Gop){agent=H(10);child=H(2);}
  if(source==H(2)&&guid==&Gop)agent=H(11);
  if(source==H(2)&&guid==&Text){if(Removed&&!BadPost)return EFI_SUCCESS;agent=H(12);child=H(3);}
  if(!agent)return EFI_UNSUPPORTED;
  e[0]=(EFI_OPEN_PROTOCOL_INFORMATION_ENTRY){agent,source,16,1};*n=1;
  if(child){e[1]=(EFI_OPEN_PROTOCOL_INFORMATION_ENTRY){agent,child,8,1};*n=2;}
  if(ExtraOwner){e[*n]=(EFI_OPEN_PROTOCOL_INFORMATION_ENTRY){H(99),source,16,1};(*n)++;}
  return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI MockStop(EFI_DRIVER_BINDING_PROTOCOL *d,EFI_HANDLE controller,UINTN n,EFI_HANDLE *children){
  if(d!=&Drivers[2] || controller!=H(2) || n!=1 || !children || children[0]!=H(3))return EFI_INVALID_PARAMETER;
  Calls++;if(FailStop)return EFI_DEVICE_ERROR;Removed=TRUE;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI FileClose(EFI_FILE_PROTOCOL *p){(void)p;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI FileFlush(EFI_FILE_PROTOCOL *p){(void)p;return FlushFail?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI FileWrite(EFI_FILE_PROTOCOL *p,UINTN *n,VOID *buffer){(void)p;(void)buffer;if(ShortWrite)(*n)--;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI FileOpen(EFI_FILE_PROTOCOL *p,EFI_FILE_PROTOCOL **out,CHAR16 *name,UINT64 mode,UINT64 attrs){
  (void)p;(void)name;(void)attrs;*out=NULL;
  if(mode==EFI_FILE_MODE_READ && !MarkerExists)return EFI_NOT_FOUND;
  MarkerExists=TRUE;*out=&Marker;return EFI_SUCCESS;
}
static EFI_STATUS RecordMock(VOID *p,const char *name,EFI_STATUS s){
  (void)p;(void)name;(void)s;Records++;return FailRecord?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static VOID Init(VOID){
  InterfaceFailure=0;Plan=(PLAN){0};Keys=Calls=Records=0;Removed=MarkerExists=BadHash=BadPost=FailRecord=FailStop=BadInventory=ExtraOwner=FALSE;
  Cancel=Timeout=ShortWrite=FlushFail=FALSE;
  Bs=(EFI_BOOT_SERVICES){0};Bs.FreePool=Free;Bs.Stall=Stall;Bs.LocateHandleBuffer=Locate;Bs.HandleProtocol=Handle;Bs.OpenProtocolInformation=Opens;Bs.ProtocolsPerHandle=ProtocolList;
  Input=(EFI_SIMPLE_TEXT_INPUT_PROTOCOL){0};Input.ReadKeyStroke=ReadKey;
  Output=(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL){0};Output.OutputString=SayMock;
  Table=(EFI_SYSTEM_TABLE){0};Table.BootServices=&Bs;Table.ConIn=&Input;Table.ConOut=&Output;Table.ConsoleOutHandle=H(3);Table.StandardErrorHandle=H(3);
  for(UINTN i=0;i<2;i++){Modes[i]=(EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE){0};Graphics[i]=(EFI_GRAPHICS_OUTPUT_PROTOCOL){0};Graphics[i].Mode=&Modes[i];}
  Modes[0].FrameBufferBase=0x100000;Modes[0].FrameBufferSize=0x200000;
  UINTN bytes[3]={0x2180,0x3bc0,0x6ae0},stops[3]={0x88c,0xb2c,0x104c};
  for(UINTN i=0;i<3;i++){
    Drivers[i]=(EFI_DRIVER_BINDING_PROTOCOL){0};Drivers[i].DriverBindingHandle=Drivers[i].ImageHandle=H(10+i);Drivers[i].Version=i?16:17;Drivers[i].Stop=MockStop;
    Images[i]=(EFI_LOADED_IMAGE_PROTOCOL){0};Images[i].ImageBase=(VOID *)((UINTN)MockStop-stops[i]);Images[i].ImageSize=bytes[i];
  }
  PciIo=(EFI_PCI_IO_PROTOCOL){0};PciIo.Pci.Read=ReadPci;
  Root=(EFI_FILE_PROTOCOL){0};Root.Open=FileOpen;Marker=(EFI_FILE_PROTOCOL){0};Marker.Close=FileClose;Marker.Write=FileWrite;Marker.Flush=FileFlush;
}
int main(VOID){
  BOOLEAN started=FALSE;EFI_STATUS s;
  Init();s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s!=EFI_SUCCESS||!started||Calls!=1||!Removed||Records<3)return 1;
  UINTN savedRecords=Records;
  if(GuEvgaTextStopVerify(&Table)!=EFI_SUCCESS || Records!=savedRecords)return 2;
  Init();BadHash=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 3;
  Init();MarkerExists=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s!=EFI_ALREADY_STARTED||Calls||started)return 4;
  Init();FailRecord=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 5;
  Init();FailStop=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls!=1||!started)return 6;
  Init();BadPost=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls!=1||!started)return 7;
  Init();BadInventory=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 8;
  Init();ExtraOwner=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 9;
  Init();Table.StandardErrorHandle=H(99);s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 10;
  Init();Drivers[2].Version++;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 11;
  Init();Drivers[2].Stop=NULL;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 12;
  Init();Cancel=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s!=EFI_ABORTED||Calls||started||MarkerExists)return 13;
  Init();Timeout=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s!=EFI_TIMEOUT||Calls||started||MarkerExists)return 14;
  Init();ShortWrite=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 15;
  Init();FlushFail=TRUE;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started)return 16;
  Init();s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s!=EFI_SUCCESS)return 17;
  ExtraOwner=TRUE;if(GuEvgaTextStopVerify(&Table)==EFI_SUCCESS)return 18;
  for(UINTN i=1;i<=4;i++){Init();InterfaceFailure=i;s=GuEvgaTextStop(&Table,&Root,RecordMock,&started);if(s==EFI_SUCCESS||Calls||started||MarkerExists)return 18+(int)i;}
  return 0;
}
