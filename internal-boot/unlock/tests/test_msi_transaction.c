/* Wrapper logic only: hashing, GPU core and EFI callbacks are mocked. */
#include "../msi-transaction.h"
#include "../compat/compat.h"
#include "../vendor/unlock_610.h"
GU_PLATFORM Gu;GU_ASSET GuAssets[5];
static EFI_SYSTEM_TABLE Table;static EFI_BOOT_SERVICES Bs;static EFI_PCI_IO_PROTOCOL Pci;
static UINT32 Config[64],Entry[9];static UINT8 Prom[0x100000],Asset;static VOID *Payloads[5];
static unsigned Mode,Graphs,ConfigReads,Unlocks,Clears,Releases,Handles;static BOOLEAN Post;
VOID GuInit(EFI_BOOT_SERVICES *b,EFI_PCI_IO_PROTOCOL *p){memset(&Gu,0,sizeof(Gu));Gu.bs=b;Gu.pci=p;}
BOOLEAN GuHashMatches(const VOID *data,UINTN bytes,const char *hash){(void)hash;return data && bytes && Mode!=1 && !(Mode==17 && bytes==sizeof(Prom));}
UINT32 GuRead32(UINT32 offset){
 const UINT32 offsets[]={0,0x118128,0x118234,0x110100,0x1fa828,0x823804,0x82381c,0x823820,0x1183a4};
 for(UINTN i=0;i<9;i++)if(offset==offsets[i]){
  if(i==6)return Post?(Mode==12?0:0x88888888U):(Mode==4?Entry[6]^1:Entry[6]);
  if(i==7)return Post?8:Entry[7];return Entry[i];
 }
 Gu.fault=TRUE;return 0xffffffff;
}
BOOLEAN GuLatchEntrySelectors(UINT32 a,UINT32 b){return Mode!=5 && Gu.prom_verified && a==Entry[6] && b==7;}
EFI_STATUS GuClearMaster(VOID){Clears++;return Mode==8?EFI_DEVICE_ERROR:EFI_SUCCESS;}
BOOLEAN GuSafeToReturn(VOID){return Mode!=9;}
int gpu_unlock_610_load_shared(struct pci_dev *p,struct gpu_unlock_610_shared *s){(void)p;(void)s;return Mode==6?-1:0;}
int gpu_unlock_610_unlock(struct pci_dev *p,const struct gpu_unlock_610_shared *s){(void)p;(void)s;Unlocks++;Gu.started=Gu.quiesced=TRUE;Post=TRUE;if(Mode==18)Gu.dma_count=1;return Mode==7?-1:0;}
VOID gpu_unlock_610_release_shared(struct gpu_unlock_610_shared *s){(void)s;Releases++;}
static EFI_STATUS EFIAPI Location(EFI_PCI_IO_PROTOCOL *p,UINTN *seg,UINTN *bus,UINTN *dev,UINTN *fn){(void)p;*seg=*dev=*fn=0;*bus=1;return Mode==20?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI Read(EFI_PCI_IO_PROTOCOL *p,EFI_PCI_IO_PROTOCOL_WIDTH width,UINT32 offset,UINTN n,VOID *out){
 (void)p;(void)width;if(offset || n!=64)return EFI_INVALID_PARAMETER;ConfigReads++;memcpy(out,Config,sizeof(Config));
 if(Mode==3 && ConfigReads==2)((UINT32 *)out)[4]^=1;
 if(Mode==16)((UINT32 *)out)[11]=0x33873842;return Mode==21?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Attr(EFI_PCI_IO_PROTOCOL *p,EFI_PCI_IO_PROTOCOL_ATTRIBUTE_OPERATION op,UINT64 a,UINT64 *out){(void)p;(void)op;(void)a;*out=Mode==15?0x600:0x200;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Handle(EFI_HANDLE h,EFI_GUID *g,VOID **out){(void)h;(void)g;Handles++;*out=Mode==14 && Handles==2?NULL:&Pci;return EFI_SUCCESS;}
static BOOLEAN MockGraph(EFI_HANDLE p,EFI_HANDLE self,EFI_PCI_IO_PROTOCOL *pci){Graphs++;return p==(VOID *)2 && self==(VOID *)1 && pci==&Pci && Mode!=2 && !(Mode==13 && Graphs>2);}
static EFI_STATUS Record(VOID *unused,const char *name,EFI_STATUS value){
 (void)unused;(void)value;if(Mode==10 && !strcmp(name,"msi-unlock-before-first-write"))return EFI_DEVICE_ERROR;
 if(Mode==11 && Unlocks)return EFI_DEVICE_ERROR;
 if(Mode==19 && !strcmp(name,"msi-unlock-transaction-complete"))return EFI_DEVICE_ERROR;return EFI_SUCCESS;
}
/* Include the real wrapper so test resets never become a firmware API. */
#include "../msi-transaction.c"
static VOID Init(VOID){
 Spent=FALSE;Graphs=ConfigReads=Unlocks=Clears=Releases=Handles=0;Post=FALSE;
 memset(Config,0,sizeof(Config));Config[0]=0x220410de;Config[1]=0x00100002;Config[2]=0x030000a1;Config[3]=0x00800010;Config[4]=0x91000000;Config[11]=0x38811462;Config[13]=0x60;
 Config[24]=0x48036801;Config[25]=8;Config[26]=0x00807805;Config[30]=0x0012b410;Config[31]=0x112c8de1;Config[32]=0x00092930;Config[45]=0x01140009;Config[50]=0x00050011;
 UINT32 initial[]={0xb72000a1,0x8b8f,0x3ff,0x10,0,0xffffff8f,0x70232144,7,0x6000};memcpy(Entry,initial,sizeof(Entry));if(Mode==22)Entry[6]=0x30232144;
 for(UINTN i=0;i<5;i++)Payloads[i]=&Asset;
 Pci=(EFI_PCI_IO_PROTOCOL){0};Pci.GetLocation=Location;Pci.Attributes=Attr;Pci.Pci.Read=Read;
 Pci.Pci.Write=(EFI_PCI_IO_PROTOCOL_CONFIG)1;Pci.Mem.Read=(EFI_PCI_IO_PROTOCOL_IO_MEM)1;Pci.Mem.Write=(EFI_PCI_IO_PROTOCOL_IO_MEM)1;
 Pci.AllocateBuffer=(EFI_PCI_IO_PROTOCOL_ALLOCATE_BUFFER)1;Pci.FreeBuffer=(EFI_PCI_IO_PROTOCOL_FREE_BUFFER)1;Pci.Map=(EFI_PCI_IO_PROTOCOL_MAP)1;Pci.Unmap=(EFI_PCI_IO_PROTOCOL_UNMAP)1;
 Bs=(EFI_BOOT_SERVICES){0};Bs.HandleProtocol=Handle;Bs.RaiseTPL=(EFI_RAISE_TPL)1;Bs.RestoreTPL=(EFI_RESTORE_TPL)1;Bs.AllocatePool=(EFI_ALLOCATE_POOL)1;Bs.FreePool=(EFI_FREE_POOL)1;Bs.Stall=(EFI_STALL)1;Table=(EFI_SYSTEM_TABLE){0};Table.BootServices=&Bs;
}
static EFI_STATUS Run(VOID){return GuMsiTransaction(&Table,(VOID *)1,(VOID *)2,&Pci,Entry,Prom,sizeof(Prom),Payloads,MockGraph,Record);}
int main(VOID){
 for(Mode=0;Mode<23;Mode++){
  Init();EFI_STATUS s=Run();BOOLEAN success=Mode==0 || Mode==22;
  if((s==EFI_SUCCESS)!=success)return 10+(int)Mode;
  if(success){if(Unlocks!=1 || Clears!=1 || Releases!=1 || !Gu.owned || Gu.armed)return 40;}
  else if(Mode==6 || Mode==7 || Mode==8 || Mode==9 || Mode==11 || Mode==12 || Mode==13 || Mode==18 || Mode==19){if(!Gu.retained)return 41;}
  else if(Unlocks)return 42;
  if(Run()!=EFI_ALREADY_STARTED)return 43;
 }
 return 0;
}
