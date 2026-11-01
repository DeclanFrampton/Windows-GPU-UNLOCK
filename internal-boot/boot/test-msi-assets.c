/* CPU-only lifetime checks; reader/hash behavior has its separate real-vector test. */
#include "../unlock/asset-reader.h"
typedef EFI_STATUS (*GU_MSI_RECORD)(VOID *,const char *,EFI_STATUS);
static UINTN Reads,Frees,Logs;static unsigned Mode;
static EFI_STATUS MockRead(EFI_BOOT_SERVICES *bs,EFI_FILE_PROTOCOL *root,const CHAR16 *path,UINTN bytes,const char *hash,VOID **out){
 (void)bs;(void)root;if(!path || !bytes || !hash)return EFI_INVALID_PARAMETER;
 Reads++;*out=NULL;if(Mode==2 && Reads==3)return EFI_CRC_ERROR;
 *out=(VOID *)(Reads*4096);return EFI_SUCCESS;
}
#define GuReadVerifiedAsset MockRead
#include "msi-assets.h"
static EFI_STATUS Record(VOID *unused,const char *name,EFI_STATUS status){
 (void)unused;(void)name;(void)status;Logs++;return Mode==3 && Logs==2?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Free(VOID *data){
 Frees++;if(data!=(VOID *)(Frees*4096))return EFI_INVALID_PARAMETER;
 return Mode==4 && Frees==3?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
int main(VOID){
 EFI_BOOT_SERVICES bs={0};bs.FreePool=Free;EFI_SYSTEM_TABLE t={0};t.BootServices=&bs;EFI_FILE_PROTOCOL root={0};
 for(Mode=1;Mode<=4;Mode++){
  Reads=Frees=Logs=0;for(UINTN i=0;i<5;i++)GuMsiPayloads[i]=NULL;
  EFI_STATUS s=GuMsiAssetsPrepare(&t,&root,Record);
  if(Frees)return 1;
  if(Mode==2){if(s!=EFI_CRC_ERROR || Reads!=3 || !GuMsiPayloads[0] || !GuMsiPayloads[1])return 2;continue;}
  if(Mode==3){if(s!=EFI_DEVICE_ERROR || Reads!=2 || !GuMsiPayloads[1])return 3;continue;}
  if(s!=EFI_SUCCESS || Reads!=5)return 4;
  s=GuMsiAssetsRelease(&t,Record);
  if(Mode==4){if(s!=EFI_DEVICE_ERROR || Frees!=3 || !GuMsiPayloads[2] || !GuMsiPayloads[4])return 5;}
  else {if(s!=EFI_SUCCESS || Frees!=5)return 6;for(UINTN i=0;i<5;i++)if(GuMsiPayloads[i])return 7;}
 }
 return 0;
}
