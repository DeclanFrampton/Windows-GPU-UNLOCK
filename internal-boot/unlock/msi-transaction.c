/* Attended exact MSI wrapper around the retained GA102 transaction core. */
#include "msi-transaction.h"
#include "msi-admission.h"
#include "compat/compat.h"
#include "vendor/unlock_610.h"
#include "format.h"
#include <stdarg.h>
#if !defined(GU_PROFILE_MSI_H510_3090) || !defined(GU_MSI_TRANSACTION_DEVELOPMENT) || !defined(GU_MSI_UNLOCK) || !defined(GU_EXPERIMENTAL_3090) || !defined(GU_ENTRY_LATCHED_SS1_FULL)
#error MSI transaction requires the explicit attended full-write build
#endif
static BOOLEAN Spent;
static GU_MSI_TRANSACTION_GRAPH Graph;
static GU_MSI_TRANSACTION_RECORD Recorder;
static EFI_STATUS LogStatus;
static EFI_STATUS Checked(const char *name,EFI_STATUS status){
 EFI_STATUS logged=Recorder(NULL,name,status);if(logged!=EFI_SUCCESS)LogStatus=logged;
 return logged==EFI_SUCCESS?status:logged;
}
static BOOLEAN VerifyGraph(VOID){
 EFI_GUID guid=EFI_PCI_IO_PROTOCOL_GUID;VOID *fresh=NULL;
 if(!Graph || Gu.bs->HandleProtocol(Gu.handle,&guid,&fresh)!=EFI_SUCCESS || fresh!=Gu.pci || !Graph(Gu.handle,Gu.image,Gu.pci))return FALSE;
 fresh=NULL;return Gu.bs->HandleProtocol(Gu.handle,&guid,&fresh)==EFI_SUCCESS && fresh==Gu.pci;
}
VOID GuLog(const char *format,...){
 char text[512];va_list args;va_start(args,format);UINTN n=GuFormatV(text,sizeof(text),format,args);va_end(args);
 if(!Recorder || n>=sizeof(text)){LogStatus=EFI_DEVICE_ERROR;if(Gu.armed)Gu.fault=TRUE;return;}
 for(UINTN offset=0;offset<n && LogStatus==EFI_SUCCESS;){
  char chunk[101];UINTN count=n-offset;if(count>100)count=100;
  for(UINTN i=0;i<count;i++){char c=text[offset+i];chunk[i]=(c=='\n' || c=='\r')?' ':c;}chunk[count]=0;
  LogStatus=Recorder(NULL,chunk,EFI_SUCCESS);offset+=count;
 }
 if(LogStatus!=EFI_SUCCESS && Gu.armed)Gu.fault=TRUE;
}
static const struct {const char *name;UINTN bytes;const char *hash;} Specs[]={
 {"gpu-unlock/610.43.03/booter_load_ga102.bin",61256,"056cbc064a888f80717726c54d7f64fcd68044d123870c95a74f37f4975dcaa4"},
 {"gpu-unlock/610.43.03/v67-ga102-610.43.03.bin",64000,"2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197"},
 {"gpu-unlock/610.43.03/gsp_ga10x.bin",84277400,"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
 {"gpu-unlock/610.43.03/gsp_boot_ga102.bin",24576,"3df651acb174fd5f5561a1996965b192f50c5d763168446ed0d4ead19d895768"},
 {"gpu-unlock/610.43.03/gsp_boot_desc_ga102.bin",84,"cc5a3fc1f4c47f2fe107b1b68f0176d8a448e6dec84b575e5560ccef5262bf15"}};
static BOOLEAN AssetsMatch(VOID) {
 for(UINTN i=0;i<5;i++)if(!GuAssets[i].name || strcmp(GuAssets[i].name,Specs[i].name) ||
  !GuAssets[i].firmware.data || GuAssets[i].firmware.size!=Specs[i].bytes ||
  !GuHashMatches(GuAssets[i].firmware.data,Specs[i].bytes,Specs[i].hash))return FALSE;
 return TRUE;
}

EFI_STATUS GuMsiTransaction(EFI_SYSTEM_TABLE *t,EFI_HANDLE self,EFI_HANDLE parent,EFI_PCI_IO_PROTOCOL *pci,
 const UINT32 entry[9],const VOID *prom,UINTN promBytes,VOID *payloads[5],GU_MSI_TRANSACTION_GRAPH graph,GU_MSI_TRANSACTION_RECORD record){
 if(!t || !t->BootServices || !self || !parent || !pci || !entry || !prom || !payloads || !graph || !record ||
  !pci->GetLocation || !pci->Pci.Read || !pci->Pci.Write || !pci->Mem.Read || !pci->Mem.Write || !pci->Attributes ||
  !pci->AllocateBuffer || !pci->FreeBuffer || !pci->Map || !pci->Unmap || !t->BootServices->HandleProtocol ||
  !t->BootServices->RaiseTPL || !t->BootServices->RestoreTPL || !t->BootServices->AllocatePool ||
  !t->BootServices->FreePool || !t->BootServices->Stall)return EFI_INVALID_PARAMETER;
 if(Spent)return EFI_ALREADY_STARTED;Spent=TRUE;Graph=graph;Recorder=record;LogStatus=EFI_SUCCESS;
 /* Wrapper already holds the proven exclusive claim. Verify it independently. */
 GuInit(t->BootServices,pci);Gu.image=self;Gu.handle=parent;Gu.bar_base=GU_MSI_BAR_BASE;Gu.bar_size=0x1000000;
 EFI_STATUS gate=Checked("msi-unlock-exclusive-graph",VerifyGraph()?EFI_SUCCESS:EFI_ACCESS_DENIED);if(gate!=EFI_SUCCESS)return gate;Gu.owned=TRUE;
 for(UINTN i=0;i<5;i++){GuAssets[i].name=Specs[i].name;GuAssets[i].firmware.data=payloads[i];GuAssets[i].firmware.size=Specs[i].bytes;}
 gate=Checked("msi-unlock-assets-match",AssetsMatch()?EFI_SUCCESS:EFI_ACCESS_DENIED);if(gate!=EFI_SUCCESS)return gate;
 UINT32 cfg[64],again[64],final[9];UINTN segment,bus,device,function;GU_CAPS caps;UINT64 attrs=0;
 EFI_STATUS s=pci->GetLocation(pci,&segment,&bus,&device,&function);if(s!=EFI_SUCCESS)return s;
 s=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,64,cfg);if(s!=EFI_SUCCESS)return s;
 gate=Checked("msi-unlock-exact-admission",GuMsiAdmit(cfg,segment,bus,device,function,entry,prom,promBytes,&caps)?EFI_SUCCESS:EFI_ACCESS_DENIED);if(gate!=EFI_SUCCESS)return gate;
 s=pci->Attributes(pci,EfiPciIoAttributeOperationGet,0,&attrs);if(s!=EFI_SUCCESS || attrs!=EFI_PCI_IO_ATTRIBUTE_MEMORY)return EFI_ACCESS_DENIED;
 Gu.pm_cap=caps.pm;Gu.pcie_cap=caps.pcie;Gu.pcie_version=caps.pcie_version;Gu.msi_cap=caps.msi;Gu.msix_cap=caps.msix;
 Gu.prom_verified=TRUE;gate=Checked("msi-unlock-entry-latched",GuLatchEntrySelectors(entry[6],entry[7])?EFI_SUCCESS:EFI_ACCESS_DENIED);if(gate!=EFI_SUCCESS)return gate;
 Gu.profile_verified=TRUE;Gu.display_ok=TRUE;Gu.display_check=VerifyGraph;
 GuLog("MSI exact profile admitted; immutable entry SS0=%#x SS1=%#x; one transaction follows.\n",entry[6],entry[7]);
 if(LogStatus!=EFI_SUCCESS || Gu.fault || !VerifyGraph())return EFI_ACCESS_DENIED;
 s=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,64,again);if(s!=EFI_SUCCESS || memcmp(cfg,again,sizeof(cfg)))return EFI_ACCESS_DENIED;
 static const UINT32 offsets[]={0,0x118128,0x118234,0x110100,0x1fa828,0x823804,0x82381c,0x823820,0x1183a4};
 for(UINTN i=0;i<9;i++){final[i]=GuRead32(offsets[i]);if(Gu.fault || final[i]!=entry[i])return EFI_ACCESS_DENIED;}
 s=record(NULL,"msi-unlock-before-first-write",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 Gu.armed=TRUE;UINT64 mask=0xffffffffULL;
 struct pci_dev gpu={.dev={.dma_mask=&mask,.coherent_dma_mask=0xffffffffULL},.pm_cap=Gu.pm_cap,.refs=1};
 struct gpu_unlock_610_shared shared={0};
 int result=gpu_unlock_610_load_shared(&gpu,&shared);
 if(!result)result=gpu_unlock_610_unlock(&gpu,&shared);
 EFI_STATUS contained=GuClearMaster();
 GuLog("MSI transaction result=%d contained=%#llx started=%u quiesced=%u fault=%u retained=%u maps=%u FLR=%u\n",result,(unsigned long long)contained,Gu.started,Gu.quiesced,Gu.fault,Gu.retained,Gu.dma_count,Gu.flrs);
 if(result || contained!=EFI_SUCCESS || LogStatus!=EFI_SUCCESS || !GuSafeToReturn() || Gu.allocations || Gu.dma_count || Gu.fault){Gu.retained=TRUE;return EFI_DEVICE_ERROR;}
 gpu_unlock_610_release_shared(&shared);Gu.armed=FALSE;
 for(UINTN pass=0;pass<2;pass++){
  UINT32 chip=GuRead32(0),ss0=GuRead32(0x82381c),ss1=GuRead32(0x823820),memory=GuRead32(0x1183a4);
  if(Gu.fault || chip!=0xb72000a1U || ss0!=0x88888888U || ss1!=8 || memory!=0x6000U || !VerifyGraph()){Gu.fault=TRUE;Gu.retained=TRUE;return EFI_DEVICE_ERROR;}
  s=record(NULL,"msi-unlock-ss0-value",ss0);if(s==EFI_SUCCESS)s=record(NULL,"msi-unlock-ss1-value",ss1);
  if(s!=EFI_SUCCESS){Gu.fault=TRUE;Gu.retained=TRUE;return s;}
  s=record(NULL,"msi-unlock-targets-verified",EFI_SUCCESS);if(s!=EFI_SUCCESS){Gu.fault=TRUE;Gu.retained=TRUE;return s;}
 }
 if(LogStatus!=EFI_SUCCESS){Gu.retained=TRUE;return LogStatus;}
 s=record(NULL,"msi-unlock-transaction-complete",EFI_SUCCESS);if(s!=EFI_SUCCESS){Gu.fault=TRUE;Gu.retained=TRUE;}
 if(s==EFI_SUCCESS)for(UINTN i=0;i<5;i++)memset(&GuAssets[i],0,sizeof(GuAssets[i]));
 return s;
}
