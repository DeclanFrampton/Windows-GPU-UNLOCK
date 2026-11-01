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
#ifdef GU_MSI_EDID_TEST
#ifndef GU_MSI_GRAPHICS_TEST
#error EDID test requires the complete prior MSI console sequence
#endif
#include "msi-edid-audit.h"
#endif
#ifdef GU_MSI_GRAPHICS_TEST
#ifndef GU_MSI_VIRTUAL_TEXT_TEST
#error Graphics membership removal requires both text removal stages
#endif
/* Read four words only from a bounded allocated-RAM range. */
static EFI_STATUS GuMsiReadWords(EFI_SYSTEM_TABLE *t,UINTN address,UINTN words[4]){
 if(!address || (address&7) || address>~(UINTN)0-32)return EFI_UNSUPPORTED;
 VOID *map=NULL;UINTN bytes=32768,key=0,stride=0;UINT32 version=0;
 EFI_STATUS s=t->BootServices->AllocatePool(EfiLoaderData,bytes,&map);if(s!=EFI_SUCCESS)return s;
 s=t->BootServices->GetMemoryMap(&bytes,map,&key,&stride,&version);BOOLEAN readable=FALSE;
 if(s==EFI_SUCCESS && stride>=sizeof(EFI_MEMORY_DESCRIPTOR) && bytes<=32768 && bytes%stride==0){
  for(UINTN at=0;at<bytes;at+=stride){
   EFI_MEMORY_DESCRIPTOR *d=(EFI_MEMORY_DESCRIPTOR *)((UINT8 *)map+at);
   if((d->Type==EfiLoaderData || d->Type==EfiBootServicesData) && !(d->Attribute&EFI_MEMORY_RP) && d->NumberOfPages<=~(UINT64)0/4096){
    UINT64 length=d->NumberOfPages*4096;
    if(d->PhysicalStart<=~(UINT64)0-length && d->PhysicalStart<=address && address-d->PhysicalStart<=length && length-(address-d->PhysicalStart)>=32)readable=TRUE;
   }
  }
 }
 if(readable)for(UINTN i=0;i<4;i++)words[i]=((UINTN *)address)[i];
 EFI_STATUS freed=t->BootServices->FreePool(map);if(freed!=EFI_SUCCESS)return freed;
 return readable?EFI_SUCCESS:EFI_UNSUPPORTED;
}
static EFI_STATUS GuMsiGraphicsPlan(EFI_SYSTEM_TABLE *t,VOID *base,UINTN size,EFI_HANDLE child,EFI_HANDLE *physical){
 if(physical)*physical=NULL;
 if(size!=0x1fa0 || *(UINTN *)((UINT8 *)base+0x1c68)!=(UINTN)child || *(UINTN *)((UINT8 *)base+0x1cc0)!=1)return EFI_UNSUPPORTED;
 UINTN head=*(UINTN *)((UINT8 *)base+0x1cc8),tail=*(UINTN *)((UINT8 *)base+0x1cd0),v[4];
 EFI_STATUS s=GuMsiReadWords(t,head,v);if(s!=EFI_SUCCESS || head!=tail || v[0] || v[1] || !v[2] || !v[3])return EFI_UNSUPPORTED;
 EFI_GUID gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,path=EFI_DEVICE_PATH_PROTOCOL_GUID;VOID *g=NULL,*p=NULL;
 if(t->BootServices->HandleProtocol((EFI_HANDLE)v[3],&gop,&g)!=EFI_SUCCESS || (UINTN)g!=v[2] ||
    t->BootServices->HandleProtocol((EFI_HANDLE)v[3],&path,&p)!=EFI_SUCCESS || !p)return EFI_UNSUPPORTED;
 /* The last-controller path frees the cached mode list before taking a
  * framebuffer snapshot. Bound and validate both directions before calling. */
 UINTN n=*(UINTN *)((UINT8 *)base+0x1ca0),node=*(UINTN *)((UINT8 *)base+0x1ca8),last=0;
 if(n>64)return EFI_UNSUPPORTED;
 for(UINTN i=0;i<n;i++){
  UINTN item[4];s=GuMsiReadWords(t,node,item);
  if(s!=EFI_SUCCESS || item[1]!=last)return EFI_UNSUPPORTED;
  last=node;node=item[0];
 }
 if(node || last!=*(UINTN *)((UINT8 *)base+0x1cb0))return EFI_UNSUPPORTED;
 if(physical)*physical=(EFI_HANDLE)v[3];return EFI_SUCCESS;
}
static EFI_STATUS GuMsiGraphicsOwner(EFI_SYSTEM_TABLE *t,EFI_HANDLE physical,EFI_HANDLE child,EFI_HANDLE agent,BOOLEAN present){
 EFI_GUID gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN n=0,drivers=0,children=0;
 EFI_STATUS s=t->BootServices->OpenProtocolInformation(physical,&gop,&opens,&n);if(s!=EFI_SUCCESS)return s;
 BOOLEAN ok=n<=256 && (!n || opens);
 if(ok)for(UINTN i=0;i<n;i++)if(opens[i].Attributes&0x18){
  if(opens[i].AgentHandle!=agent || opens[i].OpenCount!=1)ok=FALSE;
  if(opens[i].Attributes==0x10 && opens[i].ControllerHandle==physical)drivers++;
  else if(opens[i].Attributes==8 && opens[i].ControllerHandle==child)children++;
  else ok=FALSE;
 }
 if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return ok && drivers==(present?1U:0U) && children==(present?1U:0U)?EFI_SUCCESS:EFI_UNSUPPORTED;
}
#endif
#ifdef GU_MSI_VIRTUAL_TEXT_TEST
#if !defined(GU_MSI_ONE_CHILD_TEST)
#error Virtual text removal requires the one-child removal sequence
#endif
static EFI_STATUS GuMsiVirtualOwner(EFI_SYSTEM_TABLE *t,EFI_HANDLE controller,EFI_HANDLE agent,BOOLEAN present){
 EFI_GUID gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;
 EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN n=0,matches=0;
 EFI_STATUS s=t->BootServices->OpenProtocolInformation(controller,&gop,&opens,&n);
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN ok=n<=256 && (!n || opens);
 if(ok)for(UINTN i=0;i<n;i++)if(opens[i].Attributes&0x18){
  if(opens[i].AgentHandle!=agent || opens[i].Attributes!=0x10 || opens[i].ControllerHandle!=controller || opens[i].OpenCount!=1)ok=FALSE;
  matches++;
 }
 if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return ok && matches==(present?1U:0U)?EFI_SUCCESS:EFI_UNSUPPORTED;
}
static EFI_STATUS GuMsiVirtualInterfaces(EFI_SYSTEM_TABLE *t,EFI_HANDLE controller){
 EFI_GUID text=EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_GUID,gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;
 EFI_GUID extra={0xe1e4a857,0xc970,0x4075,{0xa4,0xda,0xe9,0xc4,0x1b,0x69,0xad,0xfc}};
 EFI_GUID **list=NULL;UINTN n=0,removed=0,gops=0;
 EFI_STATUS s=t->BootServices->ProtocolsPerHandle(controller,&list,&n);
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN ok=list && n<=256;
 if(ok)for(UINTN i=0;i<n;i++){
  if(!list[i]){ok=FALSE;break;}
  BOOLEAN a=TRUE,b=TRUE,c=TRUE;
  for(UINTN j=0;j<sizeof(EFI_GUID);j++){
   UINT8 v=((UINT8 *)list[i])[j];
   if(v!=((UINT8 *)&text)[j])a=FALSE;
   if(v!=((UINT8 *)&extra)[j])b=FALSE;
   if(v!=((UINT8 *)&gop)[j])c=FALSE;
  }
  removed+=a||b;gops+=c;
 }
 if(list && t->BootServices->FreePool(list)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return ok && !removed && gops==1?EFI_SUCCESS:EFI_UNSUPPORTED;
}
#endif
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
 UINTN next=1,previous=1;EFI_HANDLE controller=NULL;
 if(readable){next=*(UINTN *)node;previous=*(UINTN *)(node+8);controller=*(EFI_HANDLE *)(node+24);}
 EFI_STATUS freed=t->BootServices->FreePool(map);if(freed!=EFI_SUCCESS)return freed;
 if(!readable)return record(NULL,"msi-text-controller-memory",EFI_UNSUPPORTED)==EFI_SUCCESS?EFI_UNSUPPORTED:EFI_DEVICE_ERROR;
 EFI_GUID gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,path=EFI_DEVICE_PATH_PROTOCOL_GUID;
 VOID *g=NULL,*p=NULL;
 BOOLEAN virtualGop=controller && t->BootServices->HandleProtocol(controller,&gop,&g)==EFI_SUCCESS && g &&
  t->BootServices->HandleProtocol(controller,&path,&p)==EFI_UNSUPPORTED;
 BOOLEAN childOk=child && child==(UINTN)t->ConsoleOutHandle,single=next==0 && previous==0 &&
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
#ifdef GU_MSI_EDID_TEST
 EFI_DRIVER_BINDING_PROTOCOL *edidBinding=NULL,*nvidiaBinding=NULL;VOID *edidBase=NULL;UINTN edidMatches=0,nvidiaMatches=0;
#endif
#ifdef GU_MSI_GRAPHICS_TEST
 EFI_DRIVER_BINDING_PROTOCOL *graphicsBinding=NULL;VOID *graphicsBase=NULL;UINTN graphicsSize=0;
#endif
#ifdef GU_MSI_VIRTUAL_TEXT_TEST
 EFI_DRIVER_BINDING_PROTOCOL *virtualBinding=NULL;UINTN virtualMatches=0;
#endif
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
#ifdef GU_MSI_EDID_TEST
  if(d->Version==1 && stop==0x149c && image->ImageSize==0x9000 && GuHashMatches((UINT8 *)image->ImageBase+0x1000,14178,"333b27054df5e7d197238b860fe04e8e618712b533d1608ee9056e1b2435fcb2")){edidBinding=d;edidBase=image->ImageBase;edidMatches++;}
  if(d->Version==0x60009 && stop==0x698 && image->ImageSize==0x2b700 && GuHashMatches((UINT8 *)image->ImageBase+0x280,146818,"d045cee2113e461c7c678ec21542b1d0f18356765c0fc6a0bf2dcf824088e011")){nvidiaBinding=d;nvidiaMatches++;}
#endif
  if(d->Version==16 && stop==0x10bc && image->ImageSize>=0x2a0+21904 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,21904,"3a14de3d645d704fdd327e9e814c7b8928d98ee734d777823d3abe389d628aaa")){text++;textBinding=d;}
  if(d->Version==17 && stop==0x768 && image->ImageSize>=0x2a0+6112 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,6112,"bbfbb62cb30815f58b751879b431fff7d0a2021568b448f873407221728fb246"))gfx++;
#ifdef GU_MSI_GRAPHICS_TEST
  if(d->Version==17 && stop==0x768 && image->ImageSize==0x1fa0 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,6112,"bbfbb62cb30815f58b751879b431fff7d0a2021568b448f873407221728fb246")){graphicsBinding=d;graphicsBase=image->ImageBase;graphicsSize=(UINTN)image->ImageSize;}
#endif
#ifdef GU_MSI_VIRTUAL_TEXT_TEST
  if(d->Version==16 && stop==0xa08 && image->ImageSize==0x39a0 && GuHashMatches((UINT8 *)image->ImageBase+0x2a0,7232,"654ca7fec19bf03dabe804d0d81d47dc810788be59dea03d8c24c727281494ac")){virtualBinding=d;virtualMatches++;}
#endif
#ifdef GU_MSI_MEMBERSHIP_AUDIT
  if(textBinding==d){textBase=image->ImageBase;textSize=(UINTN)image->ImageSize;}
#endif
 }
 s=t->BootServices->FreePool(handles);if(s!=EFI_SUCCESS)return s;
 EFI_STATUS a=record(NULL,"msi-text-code-match",text==1?EFI_SUCCESS:EFI_UNSUPPORTED);
 EFI_STATUS b=record(NULL,"msi-graphics-code-match",gfx==1?EFI_SUCCESS:EFI_UNSUPPORTED);
 if(a!=EFI_SUCCESS || b!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
#ifdef GU_MSI_EDID_TEST
 if(record(NULL,"msi-edid-code-match",edidMatches==1?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS ||
    record(NULL,"msi-nvidia-code-match",nvidiaMatches==1?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(edidMatches!=1 || nvidiaMatches!=1 || !edidBinding || !edidBase || !nvidiaBinding)return EFI_UNSUPPORTED;
#endif
#ifdef GU_MSI_VIRTUAL_TEXT_TEST
 if(record(NULL,"msi-virtual-text-code-match",virtualMatches==1?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(virtualMatches!=1 || !virtualBinding)return EFI_UNSUPPORTED;
#endif
#ifdef GU_MSI_MEMBERSHIP_AUDIT
 if(text!=1 || gfx!=1 || !textBase)return EFI_UNSUPPORTED;
 (void)textBinding;
 EFI_HANDLE controller=NULL;
 s=GuMsiMembership(t,textBase,textSize,record,&controller);
#ifdef GU_MSI_ONE_CHILD_TEST
 if(s!=EFI_SUCCESS || !textBinding || !controller)return EFI_UNSUPPORTED;
#ifdef GU_MSI_GRAPHICS_TEST
 EFI_HANDLE physical=NULL;
 if(!graphicsBinding || !graphicsBase)return EFI_UNSUPPORTED;
 s=GuMsiGraphicsPlan(t,graphicsBase,graphicsSize,controller,&physical);
 if(record(NULL,"msi-graphics-plan-before",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 s=GuMsiGraphicsOwner(t,physical,controller,graphicsBinding->DriverBindingHandle,TRUE);
 if(record(NULL,"msi-graphics-owner-before",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
#ifdef GU_MSI_EDID_TEST
 s=GuMsiEdidState(t,physical,edidBinding->DriverBindingHandle,TRUE);
 if(record(NULL,"msi-edid-owner-before",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 s=GuMsiNvidiaAudit(t,physical,nvidiaBinding->DriverBindingHandle);
 if(record(NULL,"msi-nvidia-metadata-before",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
#endif
#endif
#ifdef GU_MSI_VIRTUAL_TEXT_TEST
 s=GuMsiVirtualOwner(t,controller,virtualBinding->DriverBindingHandle,TRUE);
 if(record(NULL,"msi-virtual-text-owner-before",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
#endif
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
 if(!closed)return EFI_UNSUPPORTED;
#ifdef GU_MSI_VIRTUAL_TEXT_TEST
 s=GuMsiVirtualOwner(t,controller,virtualBinding->DriverBindingHandle,TRUE);
 if(s!=EFI_SUCCESS)return s;
 if(record(NULL,"msi-virtual-text-stop-enter",EFI_SUCCESS)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 s=virtualBinding->Stop(virtualBinding,controller,0,NULL);
 if(record(NULL,"msi-virtual-text-stop-return",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 s=GuMsiVirtualOwner(t,controller,virtualBinding->DriverBindingHandle,FALSE);
 if(record(NULL,"msi-virtual-text-opens-closed",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 s=GuMsiVirtualInterfaces(t,controller);
 if(record(NULL,"msi-virtual-text-interfaces-removed",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
#ifdef GU_MSI_GRAPHICS_TEST
 if(s!=EFI_SUCCESS)return s;
 EFI_HANDLE freshPhysical=NULL;
 s=GuMsiGraphicsPlan(t,graphicsBase,graphicsSize,controller,&freshPhysical);
 if(record(NULL,"msi-graphics-plan-fresh",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS || freshPhysical!=physical)return EFI_UNSUPPORTED;
 s=GuMsiGraphicsOwner(t,physical,controller,graphicsBinding->DriverBindingHandle,TRUE);if(s!=EFI_SUCCESS)return s;
 if(record(NULL,"msi-graphics-child-stop-enter",EFI_SUCCESS)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 EFI_HANDLE aggregate=controller;
 s=graphicsBinding->Stop(graphicsBinding,physical,1,&aggregate);
 if(record(NULL,"msi-graphics-child-stop-return",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN emptyGraphics=*(UINTN *)((UINT8 *)graphicsBase+0x1cc0)==0 &&
  *(UINTN *)((UINT8 *)graphicsBase+0x1cc8)==0 && *(UINTN *)((UINT8 *)graphicsBase+0x1cd0)==0;
 if(record(NULL,"msi-graphics-list-empty",emptyGraphics?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!emptyGraphics)return EFI_UNSUPPORTED;
 s=GuMsiGraphicsOwner(t,physical,controller,graphicsBinding->DriverBindingHandle,FALSE);
 if(record(NULL,"msi-graphics-opens-closed",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN snapshotAllocated=*(UINTN *)((UINT8 *)graphicsBase+0x1c50)!=0;
 if(record(NULL,"msi-graphics-snapshot-buffer-present",snapshotAllocated?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!snapshotAllocated)return EFI_UNSUPPORTED; /* Presence does not prove Blt succeeded. */
#ifdef GU_MSI_EDID_TEST
 s=GuMsiEdidState(t,physical,edidBinding->DriverBindingHandle,TRUE);
 if(record(NULL,"msi-edid-owner-fresh",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 if(record(NULL,"msi-edid-stop-enter",EFI_SUCCESS)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 s=edidBinding->Stop(edidBinding,physical,0,NULL);
 if(record(NULL,"msi-edid-stop-return",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 s=GuMsiEdidState(t,physical,edidBinding->DriverBindingHandle,FALSE);
 if(record(NULL,"msi-edid-opens-closed",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN flagClear=*((UINT8 *)edidBase+0x5501)==0;
 if(record(NULL,"msi-edid-flag-cleared",flagClear?EFI_SUCCESS:EFI_UNSUPPORTED)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!flagClear)return EFI_UNSUPPORTED;
 s=GuMsiNvidiaAudit(t,physical,nvidiaBinding->DriverBindingHandle);
 if(record(NULL,"msi-nvidia-metadata-after",s)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
#endif
#endif
 return s;
#else
 return EFI_SUCCESS;
#endif
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
