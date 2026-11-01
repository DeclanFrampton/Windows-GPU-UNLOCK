/* Verified CPU payload storage only. Nothing is uploaded or executed. */
#pragma once
#include "../unlock/asset-reader.h"
static VOID *GuMsiPayloads[5];
static EFI_STATUS GuMsiAssetsPrepare(EFI_SYSTEM_TABLE *t,EFI_FILE_PROTOCOL *root,GU_MSI_RECORD record){
 static const struct {CHAR16 *path;UINTN bytes;const char *hash;} specs[]={
 {L"\\RTX3090-UNLOCK\\ASSETS\\booter_load_ga102.bin",61256,"056cbc064a888f80717726c54d7f64fcd68044d123870c95a74f37f4975dcaa4"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\v67-ga102-610.43.03.bin",64000,"2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\gsp_ga10x.bin",84277400,"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\gsp_boot_ga102.bin",24576,"3df651acb174fd5f5561a1996965b192f50c5d763168446ed0d4ead19d895768"},
 {L"\\RTX3090-UNLOCK\\ASSETS\\gsp_boot_desc_ga102.bin",84,"cc5a3fc1f4c47f2fe107b1b68f0176d8a448e6dec84b575e5560ccef5262bf15"},
 };
 for(UINTN i=0;i<5;i++){
  EFI_STATUS s=GuReadVerifiedAsset(t->BootServices,root,specs[i].path,specs[i].bytes,specs[i].hash,&GuMsiPayloads[i]);
  EFI_STATUS logged=record(NULL,"msi-asset-verified",s);if(s!=EFI_SUCCESS)return s;if(logged!=EFI_SUCCESS)return logged;
 }
 return record(NULL,"msi-assets-retained",EFI_SUCCESS);
}
static EFI_STATUS GuMsiAssetsRelease(EFI_SYSTEM_TABLE *t,GU_MSI_RECORD record){
 for(UINTN i=0;i<5;i++){
  if(!GuMsiPayloads[i])return EFI_UNSUPPORTED;
  EFI_STATUS s=t->BootServices->FreePool(GuMsiPayloads[i]);
  EFI_STATUS logged=record(NULL,"msi-asset-free",s);if(s!=EFI_SUCCESS)return s;
  GuMsiPayloads[i]=NULL;if(logged!=EFI_SUCCESS)return logged;
 }
 return record(NULL,"msi-assets-released",EFI_SUCCESS);
}
