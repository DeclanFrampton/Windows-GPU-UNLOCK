/* GPL-2.0-only. Shared asset reader and exclusive ownership qualification.
 * No port.c, vendor core, DMA, GPU write, reset or firmware execution linked. */
#include "evga-resources.h"
#include "../unlock/asset-reader.h"
#include "../unlock/ownership.h"
#include "../unlock/runtime.h"
GU_PLATFORM Gu;
static EFI_HANDLE OwnImage;
static GU_EVGA_RECORD Recorder;
static EFI_STATUS LogStatus;
VOID GuLog(const char *format,...) {
 (void)format;if(LogStatus==EFI_SUCCESS)LogStatus=Recorder(NULL,"evga-shared-ownership-log",EFI_SUCCESS);
}
EFI_STATUS GuEvgaResourcesPrepare(EFI_SYSTEM_TABLE *t,EFI_FILE_PROTOCOL *root,EFI_HANDLE image,GU_EVGA_RECORD record) {
 if(!t || !t->BootServices || !root || !image || !record)return EFI_INVALID_PARAMETER;
 OwnImage=image;
 static const struct {CHAR16 *path;UINTN bytes;const char *hash;} specs[]={
 {L"\\RTX3090-UNLOCK\\ASSETS\\booter_load_ga102.bin",61256,"056cbc064a888f80717726c54d7f64fcd68044d123870c95a74f37f4975dcaa4"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\v67-ga102-610.43.03.bin",64000,"2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\gsp_ga10x.bin",84277400,"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\gsp_boot_ga102.bin",24576,"3df651acb174fd5f5561a1996965b192f50c5d763168446ed0d4ead19d895768"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\gsp_boot_desc_ga102.bin",84,"cc5a3fc1f4c47f2fe107b1b68f0176d8a448e6dec84b575e5560ccef5262bf15"}};
 for(UINTN i=0;i<5;i++) {
  VOID *data=NULL;EFI_STATUS s=GuReadVerifiedAsset(t->BootServices,root,specs[i].path,specs[i].bytes,specs[i].hash,&data);
  EFI_STATUS logged=record(NULL,"evga-efi-asset-verified",s);
  EFI_STATUS freed=data?t->BootServices->FreePool(data):EFI_SUCCESS;
  if(s!=EFI_SUCCESS)return s;if(logged!=EFI_SUCCESS)return logged;if(freed!=EFI_SUCCESS)return freed;
 }
 return record(NULL,"evga-efi-assets-complete",EFI_SUCCESS);
}
EFI_STATUS GuEvgaResourcesClaim(EFI_SYSTEM_TABLE *t,EFI_HANDLE parent,EFI_PCI_IO_PROTOCOL *pci,GU_EVGA_RECORD record) {
 EFI_BOOT_SERVICES *b=t->BootServices;
 if(!OwnImage || !record || !b->RaiseTPL || !b->RestoreTPL || !b->OpenProtocol || !b->CloseProtocol)return EFI_UNSUPPORTED;
 memset(&Gu,0,sizeof(Gu));Gu.bs=b;Gu.handle=parent;Gu.image=OwnImage;Gu.pci=pci;Recorder=record;LogStatus=EFI_SUCCESS;
 EFI_STATUS s=record(NULL,"evga-shared-claim-before",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=GuClaimController();EFI_STATUS logged=record(NULL,"evga-shared-claim-return",s);
 /* Even logging failure after a successful open must close this exact ownership. */
 EFI_STATUS closed=EFI_SUCCESS;
 if(Gu.owned){closed=b->CloseProtocol(parent,&(EFI_GUID)EFI_PCI_IO_PROTOCOL_GUID,OwnImage,NULL);if(closed==EFI_SUCCESS)Gu.owned=FALSE;}
 EFI_STATUS closeLog=record(NULL,"evga-shared-close-return",closed);
 if(s!=EFI_SUCCESS)return s;if(logged!=EFI_SUCCESS)return logged;if(LogStatus!=EFI_SUCCESS)return LogStatus;
 if(closed!=EFI_SUCCESS)return closed;if(closeLog!=EFI_SUCCESS)return closeLog;
 return Gu.owned?EFI_ACCESS_DENIED:EFI_SUCCESS;
}
