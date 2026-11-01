/* GPL-2.0-only. Identity audit; optional exact zero-child method test. */
#pragma once
#if !defined(GU_DIAGNOSTIC_ONLY) || !defined(GU_DIAGNOSTIC_PROBE) || !defined(GU_PROBE_GENERIC) || defined(GU_EVGA_STOP_ONLY) || defined(GU_FULL_UNLOCK)
#error MSI audit is restricted to the generic observation build
#endif
#if defined(GU_MSI_MEMBERSHIP_AUDIT) && defined(GU_MSI_ZERO_CHILD_TEST)
#error Membership observation excludes driver method execution
#endif
#if defined(GU_MSI_ONE_CHILD_TEST) && !defined(GU_MSI_MEMBERSHIP_AUDIT)
#error One-child removal requires the bounded membership guards
#endif
#include <Protocol/DriverBinding.h>
#include <Protocol/GraphicsOutput.h>
#include <Protocol/SimpleTextOut.h>
#include "../unlock/sha256.h"
typedef EFI_STATUS (*GU_MSI_RECORD)(VOID *,const char *,EFI_STATUS);
#ifdef GU_MSI_MEMBERSHIP_AUDIT
/* Pinned text Stop uses image+0x6110 as child and image+0x6288 as a
 * singly-linked list. Read one node only, in allocated RAM, never MMIO. */
static EFI_STATUS GuMsiMembership(EFI_SYSTEM_TABLE *t,VOID *base,UINTN size,GU_MSI_RECORD record,EFI_HANDLE *controllerOut){
 if(controllerOut)*controllerOut=NULL;
 if(size<0x6298)return EFI_UNSUPPORTED;
 UINTN child=*(UINTN *)((UINT8 *)base+0x6110);
 UINTN node=*(UINTN *)((UINT8 *)base+0x6288);
 VOID *map=NULL;UINTN bytes=32768,key=0,stride=0;UINT32 version=0;
 EFI_STATUS s=t->BootServices->AllocatePool(EfiLoaderData,bytes,&map);
 if(s!=EFI_SUCCESS)return s;
 s=t->BootServices->GetMemoryMap(&bytes,map,&key,&stride,&version);
 BOOLEAN readable=FALSE;
 if(s==EFI_SUCCESS && stride>=sizeof(EFI_MEMORY_DESCRIPTOR) && bytes<=32768 && bytes%stride==0 && node && !(node&7) && node<=~(UINTN)0-32){
  for(UINTN at=0;at<bytes;at+=stride){
   EFI_MEMORY_DESCRIPTOR *d=(EFI_MEMORY_DESCRIPTOR *)((UINT8 *)map+at);
   if((d->Type==EfiBootServicesData || d->Type==EfiLoaderData) && !(d->Attribute&EFI_MEMORY_RP) && d->NumberOfPages<=~(UINT64)0/4096){
    UINT64 length=d->NumberOfPages*4096;
    if(d->PhysicalStart<=~(UINT64)0-length && d->PhysicalStart<=node && node-d->PhysicalStart<=length && length-(node-d->PhysicalStart)>=32)readable=TRUE;
   }
  }
 }
 UINTN next=1;EFI_HANDLE controller=NULL;
 if(readable){next=*(UINTN *)node;controller=*(EFI_HANDLE *)(node+24);}
 EFI_STATUS freed=t->BootServices->FreePool(map);if(freed!=EFI_SUCCESS)return freed;
 if(!readable)return record(NULL,"msi-text-controller-memory",EFI_UNSUPPORTED)==EFI_SUCCESS?EFI_UNSUPPORTED:EFI_DEVICE_ERROR;
 EFI_GUID gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,path=EFI_DEVICE_PATH_PROTOCOL_GUID;
 VOID *g=NULL,*p=NULL;
 BOOLEAN virtualGop=controller && t->BootServices->HandleProtocol(controller,&gop,&g)==EFI_SUCCESS && g &&
  t->BootServices->HandleProtocol(controller,&path,&p)==EFI_UNSUPPORTED;
 BOOLEAN childOk=child && child==(UINTN)t->ConsoleOutHandle,single=next==0 &&
  *(UINTN *)((UINT8 *)base+0x6280)==1 && *(UINTN *)((UINT8 *)base+0x6290)==node;
 if(record(NULL,"msi-text-child-is-console",childOk?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS ||
    record(NULL,"msi-text-single-controller",single?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS ||
    record(NULL,"msi-text-controller-is-virtual-gop",virtualGop?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(childOk && single && virtualGop){if(controllerOut)*controllerOut=controller;return EFI_SUCCESS;}
 return EFI_UNSUPPORTED;
}
#endif
static EFI_STATUS GuMsiRuntimeAudit(EFI_SYSTEM_TABLE *t,GU_MSI_RECORD record){
 EFI_GUID binding=EFI_DRIVER_BINDING_PROTOCOL_GUID,loaded=EFI_LOADED_IMAGE_PROTOCOL_GUID;
 EFI_HANDLE *handles=NULL;UINTN count=0,text=0,gfx=0;
 EFI_DRIVER_BINDING_PROTOCOL *textBinding=NULL;
#ifdef GU_MSI_MEMBERSHIP_AUDIT
 VOID *textBase=NULL;UINTN textSize=0;
#endif
 EFI_STATUS s=t->BootServices->LocateHandleBuffer(ByProtocol,&binding,NULL,&count,&handles);
 if(s!=EFI_SUCCESS || !handles || count>256){if(handles)t->BootServices->FreePool(handles);return EFI_UNSUPPORTED;}
 for(UINTN i=0;i<count;i++){
  EFI_DRIVER_BINDING_PROTOCOL *d=NULL;EFI_LOADED_IMAGE_PROTOCOL *image=NULL;
  if(t->BootServices->HandleProtocol(handles[i],&binding,(VOID **)&d)!=EFI_SUCCESS || !d || d->DriverBindingHandle!=handles[i] || !d->ImageHandle || !d->Stop)continue;
  if(t->BootServices->HandleProtocol(d->ImageHandle,&loaded,(VOID **)&image)!=EFI_SUCCESS || !image || !image->ImageBase)continue;
  UINTN base=(UINTN)image->ImageBase;
  if(image->ImageSize>~(UINTN)0-base || (UINTN)d->Stop<base)continue;
  UINTN stop=(UINTN)d->Stop-base;
  if(d->Version==16 && stop==0x10bc && image->ImageSize>=0x2a0+21904 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,21904,"3a14de3d645d704fdd327e9e814c7b8928d98ee734d777823d3abe389d628aaa")){text++;textBinding=d;}
  if(d->Version==17 && stop==0x768 && image->ImageSize>=0x2a0+6112 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,6112,"bbfbb62cb30815f58b751879b431fff7d0a2021568b448f873407221728fb246"))gfx++;
#ifdef GU_MSI_MEMBERSHIP_AUDIT
  if(textBinding==d){textBase=image->ImageBase;textSize=(UINTN)image->ImageSize;}
#endif
 }
 s=t->BootServices->FreePool(handles);if(s!=EFI_SUCCESS)return s;
 EFI_STATUS a=record(NULL,"msi-text-code-match",text==1?EFI_SUCCESS:EFI_UNSUPPORTED);
 EFI_STATUS b=record(NULL,"msi-graphics-code-match",gfx==1?EFI_SUCCESS:EFI_UNSUPPORTED);
 if(a!=EFI_SUCCESS || b!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
#ifdef GU_MSI_MEMBERSHIP_AUDIT
 if(text!=1 || gfx!=1 || !textBase)return EFI_UNSUPPORTED;
 (void)textBinding;
 EFI_HANDLE controller=NULL;
 s=GuMsiMembership(t,textBase,textSize,record,&controller);
#ifdef GU_MSI_ONE_CHILD_TEST
 if(s!=EFI_SUCCESS || !textBinding || !controller)return EFI_UNSUPPORTED;
 EFI_HANDLE child=t->ConsoleOutHandle;
 if(record(NULL,"msi-text-one-child-enter",EFI_SUCCESS)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 s=textBinding->Stop(textBinding,controller,1,&child);
 if(record(NULL,"msi-text-one-child-return",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN empty=*(UINTN *)((UINT8 *)textBase+0x6280)==0 &&
  *(UINTN *)((UINT8 *)textBase+0x6288)==0 && *(UINTN *)((UINT8 *)textBase+0x6290)==0;
 if(record(NULL,"msi-text-list-empty",empty?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!empty)return EFI_UNSUPPORTED;
 EFI_GUID textOut=EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_GUID;
 EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN opened=0;
 s=t->BootServices->OpenProtocolInformation(controller,&textOut,&opens,&opened);
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN closed=opened<=256 && (!opened || opens);
 if(closed)for(UINTN i=0;i<opened;i++)if(opens[i].AgentHandle==textBinding->DriverBindingHandle && (opens[i].Attributes&0x18))closed=FALSE;
 if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(record(NULL,"msi-text-opens-closed",closed?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return closed?EFI_SUCCESS:EFI_UNSUPPORTED;
#else
 return s;
#endif
#elif defined(GU_MSI_ZERO_CHILD_TEST)
 /* Exact pinned Stop returns success before using ControllerHandle when
  * NumberOfChildren is zero. This tests invocation, never child removal. */
 if(text!=1 || gfx!=1 || !textBinding || !t->ConsoleOutHandle)return EFI_UNSUPPORTED;
 if(record(NULL,"msi-text-zero-child-enter",EFI_SUCCESS)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 s=textBinding->Stop(textBinding,t->ConsoleOutHandle,0,NULL);
 if(record(NULL,"msi-text-zero-child-return",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return s;
#else
 (void)textBinding;
 return text==1 && gfx==1?EFI_SUCCESS:EFI_UNSUPPORTED;
#endif
}
