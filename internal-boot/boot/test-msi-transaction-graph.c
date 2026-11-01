/* All EFI ownership callbacks mocked. No hardware or firmware execution. */
#include <Uefi.h>
#include <Protocol/PciIo.h>
#include <Protocol/DevicePath.h>
typedef EFI_STATUS (*GU_MSI_RECORD)(VOID *,const char *,EFI_STATUS);
static unsigned Mode,Raised,Restored;
static EFI_PCI_IO_PROTOCOL Pci;
static EFI_GUID PciGuid=EFI_PCI_IO_PROTOCOL_GUID,PathGuid=EFI_DEVICE_PATH_PROTOCOL_GUID;
static EFI_GUID *Protocols[2];static EFI_OPEN_PROTOCOL_INFORMATION_ENTRY Opens[4];
static EFI_STATUS GuMsiNvParentPost(EFI_SYSTEM_TABLE *t,EFI_HANDLE p,EFI_HANDLE physical,EFI_HANDLE virtual,EFI_HANDLE agent,GU_MSI_RECORD record){
 (void)t;(void)record;return Mode==10 || p!=(VOID *)2 || physical!=(VOID *)3 || virtual!=(VOID *)4 || agent!=(VOID *)5?EFI_UNSUPPORTED:EFI_SUCCESS;
}
#include "msi-transaction-graph.h"
static EFI_TPL EFIAPI Raise(EFI_TPL level){(void)level;Raised++;return TPL_APPLICATION;}
static VOID EFIAPI Restore(EFI_TPL level){(void)level;Restored++;}
static EFI_STATUS EFIAPI Handle(EFI_HANDLE h,EFI_GUID *g,VOID **out){(void)h;(void)g;*out=Mode==9?NULL:&Pci;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI List(EFI_HANDLE h,EFI_GUID ***out,UINTN *n){(void)h;Protocols[0]=Mode==8?NULL:&PciGuid;Protocols[1]=&PathGuid;*out=Protocols;*n=Mode==13?257:2;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Info(EFI_HANDLE h,EFI_GUID *g,EFI_OPEN_PROTOCOL_INFORMATION_ENTRY **out,UINTN *n){
 (void)h;for(UINTN i=0;i<4;i++)Opens[i]=(EFI_OPEN_PROTOCOL_INFORMATION_ENTRY){0};
 if(Mode==11)return EFI_DEVICE_ERROR;
 Opens[0].Attributes=EFI_OPEN_PROTOCOL_GET_PROTOCOL;*n=1;
 if(g==&PciGuid && Mode!=1 && Mode!=15){
  Opens[1]=(EFI_OPEN_PROTOCOL_INFORMATION_ENTRY){(EFI_HANDLE)1,NULL,EFI_OPEN_PROTOCOL_EXCLUSIVE,1};*n=2;
  if(Mode==2)Opens[1].AgentHandle=(EFI_HANDLE)99;
  if(Mode==3)Opens[1].ControllerHandle=(EFI_HANDLE)2;
  if(Mode==4)Opens[1].Attributes=EFI_OPEN_PROTOCOL_BY_DRIVER;
  if(Mode==5)Opens[1].OpenCount=2;
  if(Mode==6){Opens[2]=Opens[1];*n=3;}
 }
 if(g==&PathGuid && (Mode==7 || Mode==15)){Opens[1]=(EFI_OPEN_PROTOCOL_INFORMATION_ENTRY){(EFI_HANDLE)1,NULL,EFI_OPEN_PROTOCOL_EXCLUSIVE,1};*n=2;}
 if(Mode==14)*n=65;*out=Opens;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Free(VOID *p){(void)p;return Mode==12?EFI_DEVICE_ERROR:EFI_SUCCESS;}
int main(VOID){
 EFI_BOOT_SERVICES bs={0};bs.RaiseTPL=Raise;bs.RestoreTPL=Restore;bs.HandleProtocol=Handle;bs.ProtocolsPerHandle=List;bs.OpenProtocolInformation=Info;bs.FreePool=Free;
 EFI_SYSTEM_TABLE t={0};t.BootServices=&bs;
 for(Mode=0;Mode<17;Mode++){
  MsiGraphTable=NULL;Raised=Restored=0;
  if(GuMsiSetTransactionGraph(&t,(VOID *)1,(VOID *)2,(VOID *)3,(VOID *)4,(VOID *)5)!=EFI_SUCCESS)return 1;
  if(GuMsiSetTransactionGraph(&t,(VOID *)1,(VOID *)2,(VOID *)3,(VOID *)4,(VOID *)5)!=EFI_ACCESS_DENIED)return 2;
  BOOLEAN ok=MsiTransactionGraph((VOID *)2,Mode==16?(VOID *)9:(VOID *)1,&Pci);
  if(ok!=(Mode==0))return 20+(int)Mode;
  if(Raised!=Restored || Raised!=(Mode==16?0U:1U))return 50;
 }
 return 0;
}
