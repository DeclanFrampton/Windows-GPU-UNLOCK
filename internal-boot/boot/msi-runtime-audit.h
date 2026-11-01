/* GPL-2.0-only. Read loaded-image bytes and binding metadata; never call Stop. */
#pragma once
#if !defined(GU_DIAGNOSTIC_ONLY) || !defined(GU_DIAGNOSTIC_PROBE) || !defined(GU_PROBE_GENERIC) || defined(GU_EVGA_STOP_ONLY) || defined(GU_FULL_UNLOCK)
#error MSI audit is restricted to the generic observation build
#endif
#include <Protocol/DriverBinding.h>
#include "../unlock/sha256.h"
typedef EFI_STATUS (*GU_MSI_RECORD)(VOID *,const char *,EFI_STATUS);
static EFI_STATUS GuMsiRuntimeAudit(EFI_SYSTEM_TABLE *t,GU_MSI_RECORD record){
 EFI_GUID binding=EFI_DRIVER_BINDING_PROTOCOL_GUID,loaded=EFI_LOADED_IMAGE_PROTOCOL_GUID;
 EFI_HANDLE *handles=NULL;UINTN count=0,text=0,gfx=0;
 EFI_STATUS s=t->BootServices->LocateHandleBuffer(ByProtocol,&binding,NULL,&count,&handles);
 if(s!=EFI_SUCCESS || !handles || count>256){if(handles)t->BootServices->FreePool(handles);return EFI_UNSUPPORTED;}
 for(UINTN i=0;i<count;i++){
  EFI_DRIVER_BINDING_PROTOCOL *d=NULL;EFI_LOADED_IMAGE_PROTOCOL *image=NULL;
  if(t->BootServices->HandleProtocol(handles[i],&binding,(VOID **)&d)!=EFI_SUCCESS || !d || d->DriverBindingHandle!=handles[i] || !d->ImageHandle || !d->Stop)continue;
  if(t->BootServices->HandleProtocol(d->ImageHandle,&loaded,(VOID **)&image)!=EFI_SUCCESS || !image || !image->ImageBase)continue;
  UINTN base=(UINTN)image->ImageBase;
  if(image->ImageSize>~(UINTN)0-base || (UINTN)d->Stop<base)continue;
  UINTN stop=(UINTN)d->Stop-base;
  if(d->Version==16 && stop==0x10bc && image->ImageSize>=0x2a0+21904 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,21904,"3a14de3d645d704fdd327e9e814c7b8928d98ee734d777823d3abe389d628aaa"))text++;
  if(d->Version==17 && stop==0x768 && image->ImageSize>=0x2a0+6112 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,6112,"bbfbb62cb30815f58b751879b431fff7d0a2021568b448f873407221728fb246"))gfx++;
 }
 s=t->BootServices->FreePool(handles);if(s!=EFI_SUCCESS)return s;
 EFI_STATUS a=record(NULL,"msi-text-code-match",text==1?EFI_SUCCESS:EFI_UNSUPPORTED);
 EFI_STATUS b=record(NULL,"msi-graphics-code-match",gfx==1?EFI_SUCCESS:EFI_UNSUPPORTED);
 if(a!=EFI_SUCCESS || b!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return text==1 && gfx==1?EFI_SUCCESS:EFI_UNSUPPORTED;
}
