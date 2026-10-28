/* GPL-2.0-only. Pinned EVGA consumer Stop sequence. No unlock. */
#include "evga-text-stop.h"
#include <Protocol/GraphicsOutput.h>
#include <Protocol/DevicePath.h>
#include <Protocol/DriverBinding.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/PciIo.h>
#include "../unlock/sha256.h"

static EFI_GUID Gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,Text=EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_GUID;
static EFI_GUID Path=EFI_DEVICE_PATH_PROTOCOL_GUID,Binding=EFI_DRIVER_BINDING_PROTOCOL_GUID;
static EFI_GUID Loaded=EFI_LOADED_IMAGE_PROTOCOL_GUID,Pci=EFI_PCI_IO_PROTOCOL_GUID;
typedef struct {EFI_HANDLE Physical,Virtual,Console,Gfx,VirtualText,TextAgent;EFI_DRIVER_BINDING_PROTOCOL *Driver;} PLAN;
static PLAN Plan;
#ifdef GU_EVGA_AUDIT_NVIDIA
static EFI_HANDLE NvidiaParent,NvidiaAgent,NvidiaStoredChild;
static UINTN NvidiaChildClass,NvidiaFlag;
static BOOLEAN NvidiaSaved;
#endif
#ifdef GU_EVGA_RELEASE_EDID
#include <Protocol/EdidDiscovered.h>
static EFI_GUID Edid=EFI_EDID_DISCOVERED_PROTOCOL_GUID;
static EFI_HANDLE EdidAgent,EdidHandles[3];
static EFI_DRIVER_BINDING_PROTOCOL *EdidDriver;
static BOOLEAN EdidReleased;
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
static EFI_HANDLE EdidSiblingReleased[2];
#endif
#endif
#ifdef GU_EVGA_RELEASE_TEXT
static EFI_DRIVER_BINDING_PROTOCOL *VirtualDriver;
static BOOLEAN TextReleased;
#ifdef GU_EVGA_RELEASE_GRAPHICS
static EFI_DRIVER_BINDING_PROTOCOL *GraphicsDriver;
static BOOLEAN GraphicsReleased;
#undef ATTEMPT_PATH
#ifdef GU_EVGA_RELEASE_EDID
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
#ifdef GU_EVGA_AUDIT_NVIDIA
#define ATTEMPT_PATH L"\\RTX3090-UNLOCK\\EVGA-NVIDIA-AUDIT.ARMED"
#else
#define ATTEMPT_PATH L"\\RTX3090-UNLOCK\\EVGA-EDID-SIBLINGS.ARMED"
#endif
#else
#define ATTEMPT_PATH L"\\RTX3090-UNLOCK\\EVGA-EDID-RELEASE.ARMED"
#endif
#else
#define ATTEMPT_PATH L"\\RTX3090-UNLOCK\\EVGA-GFX-RELEASE.ARMED"
#endif
#else
#define ATTEMPT_PATH L"\\RTX3090-UNLOCK\\EVGA-TEXT-RELEASE.ARMED"
#endif
#else
#define ATTEMPT_PATH L"\\RTX3090-UNLOCK\\EVGA-TEXT-STOP.ARMED"
#endif
static EFI_STATUS Checked(GU_EVGA_RECORD record,const char *event,EFI_STATUS status) {
  if(record){EFI_STATUS io=record(NULL,event,status);if(io!=EFI_SUCCESS)return io;}
  return status;
}
static EFI_STATUS Value(GU_EVGA_RECORD record,const char *label,UINT64 value) {
  if(!record)return EFI_SUCCESS;
  char event[100];UINTN n=0;
  while(*label && n<70)event[n++]=*label++;
  event[n++]='=';event[n++]='0';event[n++]='x';
  for(int i=15;i>=0;i--)event[n++]="0123456789abcdef"[(value>>(i*4))&15];
  event[n]=0;return record(NULL,event,EFI_SUCCESS);
}
static EFI_STATUS Edges(EFI_BOOT_SERVICES *b,EFI_HANDLE source,EFI_GUID *protocol,
                       EFI_HANDLE child,BOOLEAN pair,EFI_HANDLE *owner,BOOLEAN absent) {
  EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=NULL;UINTN n=0,drivers=0,children=0;EFI_HANDLE agent=NULL;
  EFI_STATUS s=b->OpenProtocolInformation(source,protocol,&e,&n);
  if(s!=EFI_SUCCESS || n>64 || (n && !e))return EFI_COMPROMISED_DATA;
  for(UINTN i=0;i<n;i++) {
    if(e[i].Attributes==1 || e[i].Attributes==2 || e[i].Attributes==4)continue;
    if(absent){s=EFI_ACCESS_DENIED;break;}
    if(e[i].OpenCount!=1){s=EFI_ACCESS_DENIED;break;}
    if(e[i].Attributes==EFI_OPEN_PROTOCOL_BY_DRIVER && e[i].ControllerHandle==source) {
      drivers++;if(agent && agent!=e[i].AgentHandle){s=EFI_ACCESS_DENIED;break;}agent=e[i].AgentHandle;
    } else if(pair && e[i].Attributes==EFI_OPEN_PROTOCOL_BY_CHILD_CONTROLLER && e[i].ControllerHandle==child) {
      children++;if(agent && agent!=e[i].AgentHandle){s=EFI_ACCESS_DENIED;break;}agent=e[i].AgentHandle;
    } else {s=EFI_ACCESS_DENIED;break;}
  }
  if(s==EFI_SUCCESS && !absent && (drivers!=1 || children!=(pair?1U:0U) || !agent))s=EFI_ACCESS_DENIED;
  if(e && b->FreePool(e)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
  if(s==EFI_SUCCESS && !absent) {
    if(*owner && *owner!=agent)return EFI_ACCESS_DENIED;
    *owner=agent;
  }
  return s;
}
static EFI_STATUS Code(EFI_BOOT_SERVICES *b,EFI_HANDLE agent,UINTN bytes,UINTN codeRva,UINTN codeBytes,
                       UINTN stop,UINT32 version,const char *hash,EFI_DRIVER_BINDING_PROTOCOL **out,GU_EVGA_RECORD record) {
  EFI_DRIVER_BINDING_PROTOCOL *d=NULL;EFI_LOADED_IMAGE_PROTOCOL *image=NULL;
  EFI_STATUS s=b->HandleProtocol(agent,&Binding,(VOID **)&d);
  if(s==EFI_SUCCESS && d){s=Value(record,"evga-observed-binding-version",d->Version);if(s!=EFI_SUCCESS)return s;}
  if(s!=EFI_SUCCESS || !d || d->DriverBindingHandle!=agent || !d->ImageHandle || !d->Stop || d->Version!=version)return Checked(record,"evga-code-binding",EFI_UNSUPPORTED);
  s=b->HandleProtocol(d->ImageHandle,&Loaded,(VOID **)&image);
  if(s==EFI_SUCCESS && image){s=Value(record,"evga-observed-image-bytes",image->ImageSize);if(s!=EFI_SUCCESS)return s;}
  if(s!=EFI_SUCCESS || !image || !image->ImageBase || image->ImageSize!=bytes || bytes<=codeRva || codeBytes>bytes-codeRva)return Checked(record,"evga-code-loaded-image",EFI_UNSUPPORTED);
  UINTN base=(UINTN)image->ImageBase;
  if((UINTN)d->Stop>=base){s=Value(record,"evga-observed-stop-rva",(UINTN)d->Stop-base);if(s!=EFI_SUCCESS)return s;}
  if(base>~(UINTN)0-bytes || (UINTN)d->Stop!=base+stop || stop<codeRva || stop-codeRva>=codeBytes)return Checked(record,"evga-code-stop-address",EFI_UNSUPPORTED);
  if(!GuHashMatches((UINT8 *)image->ImageBase+codeRva,codeBytes,hash))return Checked(record,"evga-code-section-hash",EFI_CRC_ERROR);
  if(out)*out=d;return EFI_SUCCESS;
}
static EFI_STATUS Inventory(EFI_BOOT_SERVICES *b,GU_EVGA_RECORD record) {
  EFI_HANDLE *handles=NULL;UINTN count=0,displays=0,matches=0;
  EFI_STATUS s=b->LocateHandleBuffer(ByProtocol,&Pci,NULL,&count,&handles);
  if(s!=EFI_SUCCESS || !handles || !count || count>1024)return EFI_UNSUPPORTED;
  for(UINTN i=0;i<count;i++) {
    EFI_PCI_IO_PROTOCOL *pci=NULL;UINT32 cfg[16];
    s=b->HandleProtocol(handles[i],&Pci,(VOID **)&pci);
    if(s!=EFI_SUCCESS || !pci){s=EFI_UNSUPPORTED;break;}
    s=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,16,cfg);if(s!=EFI_SUCCESS)break;
    if((cfg[2]>>24)==3){displays++;if(cfg[0]==0x220410deU && cfg[11]==0x33873842U){matches++;
#ifdef GU_EVGA_AUDIT_NVIDIA
      NvidiaParent=handles[i];
#endif
    }}
  }
  if(b->FreePool(handles)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
  EFI_STATUS io=Value(record,"evga-observed-display-count",displays);if(io!=EFI_SUCCESS)return io;
  io=Value(record,"evga-observed-matching-card-count",matches);if(io!=EFI_SUCCESS)return io;
  return s==EFI_SUCCESS && displays==1 && matches==1?EFI_SUCCESS:EFI_UNSUPPORTED;
}
/* Enumerate membership: this firmware returns a pointer for an unlisted GOP. */
static EFI_STATUS ConsoleProtocols(EFI_SYSTEM_TABLE *t,GU_EVGA_RECORD record) {
  EFI_GUID **list=NULL;UINTN n=0,gops=0,texts=0;
  EFI_STATUS s=t->BootServices->ProtocolsPerHandle(t->ConsoleOutHandle,&list,&n);
  EFI_STATUS io=Checked(record,"evga-console-protocol-list",s);if(io!=s)return io;
  if(s!=EFI_SUCCESS || !list || n>256)return EFI_UNSUPPORTED;
  EFI_GUID expectedGop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,expectedText=EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_GUID;
  for(UINTN i=0;i<n;i++) {
    if(!list[i]){s=EFI_COMPROMISED_DATA;break;}
    BOOLEAN g=TRUE,x=TRUE;
    for(UINTN j=0;j<sizeof(EFI_GUID);j++) {
      if(((UINT8 *)list[i])[j]!=((UINT8 *)&expectedGop)[j])g=FALSE;
      if(((UINT8 *)list[i])[j]!=((UINT8 *)&expectedText)[j])x=FALSE;
    }
    gops+=g;texts+=x;
  }
  if(t->BootServices->FreePool(list)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
  if(s!=EFI_SUCCESS)return s;
  io=Value(record,"evga-console-listed-gops",gops);if(io!=EFI_SUCCESS)return io;
  io=Value(record,"evga-console-listed-texts",texts);if(io!=EFI_SUCCESS)return io;
  return gops==0 && texts==1?EFI_SUCCESS:EFI_UNSUPPORTED;
}
#ifdef GU_EVGA_RELEASE_TEXT
static EFI_STATUS VirtualInterfaces(EFI_SYSTEM_TABLE *t,BOOLEAN released) {
  EFI_GUID **list=NULL;UINTN n=0,texts=0,ugas=0,extras=0;
  EFI_GUID uga={0xd3b36f2c,0xd551,0x11d4,{0x9a,0x46,0,0x90,0x27,0x3f,0xc1,0x4d}};
  EFI_GUID extra={0xe1e4a857,0xc970,0x4075,{0xa4,0xda,0xe9,0xc4,0x1b,0x69,0xad,0xfc}};
  EFI_STATUS s=t->BootServices->ProtocolsPerHandle(Plan.Virtual,&list,&n);
  if(s!=EFI_SUCCESS || !list || n>256)return EFI_UNSUPPORTED;
  for(UINTN i=0;i<n;i++) {
    if(!list[i]){s=EFI_COMPROMISED_DATA;break;}
    BOOLEAN x=TRUE,u=TRUE,e=TRUE;
    for(UINTN j=0;j<sizeof(EFI_GUID);j++) {
      UINT8 v=((UINT8 *)list[i])[j];
      if(v!=((UINT8 *)&Text)[j])x=FALSE;
      if(v!=((UINT8 *)&uga)[j])u=FALSE;
      if(v!=((UINT8 *)&extra)[j])e=FALSE;
    }
    texts+=x;ugas+=u;extras+=e;
  }
  if(t->BootServices->FreePool(list)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
  if(s!=EFI_SUCCESS)return s;
  return ugas==0 && texts==(released?0U:1U) && extras==(released?0U:1U)?EFI_SUCCESS:EFI_ACCESS_DENIED;
}
#endif
#ifdef GU_EVGA_RELEASE_EDID
static EFI_STATUS EdidState(EFI_SYSTEM_TABLE *t,GU_EVGA_RECORD record) {
  EFI_BOOT_SERVICES *b=t->BootServices;EFI_HANDLE *handles=NULL;UINTN n=0;
  EFI_STATUS s=b->LocateHandleBuffer(ByProtocol,&Edid,NULL,&n,&handles);
  if(s!=EFI_SUCCESS || !handles || n!=3){if(handles)b->FreePool(handles);return EFI_UNSUPPORTED;}
  UINTN physical=0;
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
  UINTN pathBits=0;
#endif
  for(UINTN i=0;i<n;i++) {
    for(UINTN j=0;j<i;j++)if(handles[j]==handles[i])s=EFI_COMPROMISED_DATA;
    if(s!=EFI_SUCCESS)break;
    if(EdidHandles[0]) {
      BOOLEAN found=FALSE;for(UINTN j=0;j<3;j++)if(EdidHandles[j]==handles[i])found=TRUE;
      if(!found){s=EFI_ACCESS_DENIED;break;}
    }
    if(handles[i]==Plan.Physical)physical++;
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
    /* Exact captured PCI parent plus three distinct ACPI ADR children. */
    static const UINT8 expected[36]={0x02,0x01,0x0c,0x00,0xd0,0x41,0x03,0x0a,0,0,0,0,0x01,0x01,0x06,0,0,1,0x01,0x01,0x06,0,0,0,0x02,0x03,0x08,0,0x20,0x03,0x01,0x80,0x7f,0xff,4,0};
    UINT8 *path=NULL;s=b->HandleProtocol(handles[i],&Path,(VOID **)&path);
    if(s!=EFI_SUCCESS || !path){s=EFI_UNSUPPORTED;break;}
    for(UINTN off=0;off<36;) {
      for(UINTN j=0;j<4;j++)if(path[off+j]!=expected[off+j])s=EFI_ACCESS_DENIED;
      if(s!=EFI_SUCCESS)break;
      UINTN length=expected[off+2];
      for(UINTN j=4;j<length;j++)if(off+j!=28 && path[off+j]!=expected[off+j])s=EFI_ACCESS_DENIED;
      if(s!=EFI_SUCCESS)break;off+=length;
    }
    if(s!=EFI_SUCCESS)break;
    UINTN bit=path[28]==0x20?1:(path[28]==0x40?2:(path[28]==0x70?4:0));
    if(!bit || (pathBits&bit) || ((handles[i]==Plan.Physical)!=(bit==1)))s=EFI_ACCESS_DENIED;
    if(s!=EFI_SUCCESS)break;pathBits|=bit;
#endif
    BOOLEAN absent=EdidReleased && handles[i]==Plan.Physical;
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
    for(UINTN j=0;j<2;j++)if(EdidSiblingReleased[j]==handles[i])absent=TRUE;
#endif
    s=Edges(b,handles[i],&Edid,NULL,FALSE,&EdidAgent,absent);
    if(s!=EFI_SUCCESS)break;
  }
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
  if(s==EFI_SUCCESS && pathBits!=7)s=EFI_ACCESS_DENIED;
#endif
  if(s==EFI_SUCCESS && physical!=1)s=EFI_ACCESS_DENIED;
  if(s==EFI_SUCCESS && !EdidHandles[0])for(UINTN i=0;i<3;i++)EdidHandles[i]=handles[i];
  if(b->FreePool(handles)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
  s=Checked(record,"evga-edid-edges",s);if(s!=EFI_SUCCESS)return s;
  return Checked(record,"evga-edid-code",Code(b,EdidAgent,0x9000,0x1000,0x37da,0x14d4,1,"a015d52f55fa6441414458e2b699ba2edcb53f03b001ac6367e45bcd908c418e",&EdidDriver,record));
}
#endif
static EFI_STATUS Graph(EFI_SYSTEM_TABLE *t,BOOLEAN after,GU_EVGA_RECORD record) {
  EFI_BOOT_SERVICES *b=t->BootServices;EFI_HANDLE *handles=NULL;UINTN count=0;
  EFI_STATUS s=b->LocateHandleBuffer(ByProtocol,&Gop,NULL,&count,&handles);
  if(s!=EFI_SUCCESS || !handles || count!=2){if(handles)b->FreePool(handles);return Checked(record,"evga-gop-inventory",EFI_UNSUPPORTED);}
  EFI_HANDLE physical=NULL,virtual=NULL;
  for(UINTN i=0;i<count;i++) {
    EFI_GRAPHICS_OUTPUT_PROTOCOL *g=NULL;VOID *path=NULL;
    s=b->HandleProtocol(handles[i],&Gop,(VOID **)&g);
    if(s!=EFI_SUCCESS || !g || !g->Mode){s=EFI_UNSUPPORTED;break;}
    EFI_STATUS ps=b->HandleProtocol(handles[i],&Path,&path);
    if(ps==EFI_SUCCESS && path && g->Mode->FrameBufferBase && g->Mode->FrameBufferSize && !physical)physical=handles[i];
    else if(ps==EFI_UNSUPPORTED && !g->Mode->FrameBufferBase && !g->Mode->FrameBufferSize && !virtual)virtual=handles[i];
    else {s=EFI_UNSUPPORTED;break;}
  }
  if(b->FreePool(handles)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
  if(s!=EFI_SUCCESS || !physical || !virtual || !t->ConsoleOutHandle || t->StandardErrorHandle!=t->ConsoleOutHandle)return Checked(record,"evga-gop-shape",EFI_UNSUPPORTED);
  s=Checked(record,"evga-console-membership",ConsoleProtocols(t,record));if(s!=EFI_SUCCESS)return s;
  VOID *text=NULL;EFI_STATUS io;
#ifdef GU_EVGA_RELEASE_TEXT
  if(!TextReleased) {
#endif
  s=b->HandleProtocol(virtual,&Text,&text);
  io=Checked(record,"evga-virtual-text-interface",s);if(io!=s)return io;
  if(s!=EFI_SUCCESS || !text)return Checked(record,"evga-virtual-text-interface-valid",EFI_UNSUPPORTED);
#ifdef GU_EVGA_RELEASE_TEXT
  }
#endif
  text=NULL;s=b->HandleProtocol(t->ConsoleOutHandle,&Text,&text);
  io=Checked(record,"evga-system-text-interface",s);if(io!=s)return io;
  if(s!=EFI_SUCCESS || !text)return Checked(record,"evga-system-text-interface-valid",EFI_UNSUPPORTED);
  if(Plan.Physical && (Plan.Physical!=physical || Plan.Virtual!=virtual || Plan.Console!=t->ConsoleOutHandle))return EFI_ACCESS_DENIED;
  Plan.Physical=physical;Plan.Virtual=virtual;Plan.Console=t->ConsoleOutHandle;
  s=Checked(record,"evga-gfx-edges",Edges(b,physical,&Gop,virtual,TRUE,&Plan.Gfx,
#ifdef GU_EVGA_RELEASE_GRAPHICS
    GraphicsReleased
#else
    FALSE
#endif
  ));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-virtual-text-edges",Edges(b,virtual,&Gop,NULL,FALSE,&Plan.VirtualText,
#ifdef GU_EVGA_RELEASE_TEXT
    TextReleased
#else
    FALSE
#endif
  ));if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_TEXT
  if(TextReleased) {
    s=Checked(record,"evga-virtual-interfaces-removed",VirtualInterfaces(t,TRUE));if(s!=EFI_SUCCESS)return s;
  } else {
#endif
  s=Checked(record,"evga-text-splitter-edges",Edges(b,virtual,&Text,Plan.Console,TRUE,&Plan.TextAgent,after));if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_TEXT
  }
#endif
  s=Checked(record,"evga-gfx-code",Code(b,Plan.Gfx,0x2180,0x2a0,0x1990,0x88c,17,"3f4c4ea26023ddf00990b59385d0fcf3139acb583c70406828777cdceab8cecb",
#ifdef GU_EVGA_RELEASE_GRAPHICS
    &GraphicsDriver,
#else
    NULL,
#endif
    record));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-virtual-text-code",Code(b,Plan.VirtualText,0x3bc0,0x2a0,0x1e00,0xb2c,16,"e5e68f0856c6e932da9bf3c680bac955dbf180eb083da78b64007388d89e24a7",
#ifdef GU_EVGA_RELEASE_TEXT
    &VirtualDriver,
#else
    NULL,
#endif
    record));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-text-splitter-code",Code(b,Plan.TextAgent,0x6ae0,0x2a0,0x5620,0x104c,16,"e2b072199726ae784f749057c3c5453ed8db0bb3fbe1a73ccca7e6f302325291",&Plan.Driver,record));
  if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_EDID
  return EdidState(t,record);
#else
  return EFI_SUCCESS;
#endif
}
#ifdef GU_EVGA_AUDIT_NVIDIA
/* CPU protocol data only. Never call NVIDIA Stop or any private method. */
static EFI_STATUS NvidiaAudit(EFI_SYSTEM_TABLE *t,GU_EVGA_RECORD record) {
  EFI_BOOT_SERVICES *b=t->BootServices;
  if(!NvidiaParent)return EFI_UNSUPPORTED;
  EFI_STATUS s=Checked(record,"evga-nvidia-pci-owner",Edges(b,NvidiaParent,&Pci,NULL,FALSE,&NvidiaAgent,FALSE));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-nvidia-code",Code(b,NvidiaAgent,0x2b700,0x280,0x23d82,0x698,0x60009,"d045cee2113e461c7c678ec21542b1d0f18356765c0fc6a0bf2dcf824088e011",NULL,record));if(s!=EFI_SUCCESS)return s;
  EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=NULL;UINTN n=0,bits=0;
  s=b->OpenProtocolInformation(NvidiaParent,&Path,&e,&n);
  if(s!=EFI_SUCCESS || n>64 || (n&&!e))return EFI_COMPROMISED_DATA;
  for(UINTN i=0;i<n;i++) {
    if(e[i].Attributes==1 || e[i].Attributes==2 || e[i].Attributes==4)continue;
    UINTN bit=0;for(UINTN j=0;j<3;j++)if(e[i].ControllerHandle==EdidHandles[j])bit=(UINTN)1<<j;
    if(e[i].Attributes!=8 || e[i].OpenCount!=1 || e[i].AgentHandle!=NvidiaAgent || !bit || (bits&bit)){s=EFI_ACCESS_DENIED;break;}
    bits|=bit;
  }
  if(e && b->FreePool(e)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
  if(s==EFI_SUCCESS && bits!=7)s=EFI_ACCESS_DENIED;
  s=Checked(record,"evga-nvidia-three-children",s);if(s!=EFI_SUCCESS)return s;
  EFI_GUID privateGuid={0xfe47349a,0x7f0d,0x4641,{0x82,0x2b,0x34,0xba,0xa2,0x8e,0xcd,0xd0}};
  UINT8 *context=NULL;s=b->HandleProtocol(NvidiaParent,&privateGuid,(VOID **)&context);
  s=Checked(record,"evga-nvidia-private-interface",s);if(s!=EFI_SUCCESS || !context)return EFI_UNSUPPORTED;
  if((UINTN)context>~(UINTN)0-0x99)return EFI_COMPROMISED_DATA;
  EFI_HANDLE child=*(EFI_HANDLE *)(context+0x88);UINTN flag=context[0x98];
  UINTN kind=child?4:0;
  if(child==Plan.Physical)kind=1;
  else for(UINTN j=0;j<3;j++)if(child==EdidHandles[j])kind=2;
  s=Value(record,"evga-nvidia-stored-child-class",kind);if(s!=EFI_SUCCESS)return s;
  s=Value(record,"evga-nvidia-parent-flag98",flag);if(s!=EFI_SUCCESS)return s;
  /* Classes:0 null,1 physical GOP,2 EDID-only sibling,4 unknown. */
  if(kind==4 || flag>1)return EFI_UNSUPPORTED;
  if(NvidiaSaved && (child!=NvidiaStoredChild || kind!=NvidiaChildClass || flag!=NvidiaFlag))return EFI_ACCESS_DENIED;
  NvidiaStoredChild=child;NvidiaChildClass=kind;NvidiaFlag=flag;NvidiaSaved=TRUE;
  return Checked(record,"evga-nvidia-audit",EFI_SUCCESS);
}
#endif
EFI_STATUS GuEvgaTextStopVerify(EFI_SYSTEM_TABLE *t) {
  if(!t || !t->BootServices || !Plan.Driver || !Plan.TextAgent)return EFI_INVALID_PARAMETER;
  EFI_STATUS s=Graph(t,TRUE,NULL); /* Files are closed: no logging on the final check. */
#ifdef GU_EVGA_AUDIT_NVIDIA
  if(s==EFI_SUCCESS)s=NvidiaAudit(t,NULL);
#endif
  return s;
}
EFI_STATUS GuEvgaTextStop(EFI_SYSTEM_TABLE *t,EFI_FILE_PROTOCOL *root,GU_EVGA_RECORD record,BOOLEAN *started) {
  if(!t || !t->BootServices || !t->ConIn || !root || !record || !started)return EFI_INVALID_PARAMETER;
  *started=FALSE;EFI_STATUS s=Checked(record,"evga-pci-inventory",Inventory(t->BootServices,record));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-initial-graph",Graph(t,FALSE,record));if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_AUDIT_NVIDIA
  s=NvidiaAudit(t,record);if(s!=EFI_SUCCESS)return s;
#endif
  if(!t->ConOut || !t->ConOut->OutputString)return EFI_UNSUPPORTED;
  s=t->ConOut->OutputString(t->ConOut,L"Live guards passed. NOW press fresh Shift+G once (60 seconds); Esc cancels.\r\n");
  if(s!=EFI_SUCCESS)return s;
  /* Wait for a fresh uppercase G, not a key left over from the boot menu. */
  EFI_INPUT_KEY key;
  for(UINTN i=0;i<64;i++) {
    s=t->ConIn->ReadKeyStroke(t->ConIn,&key);if(s==EFI_NOT_READY)break;
    if(s!=EFI_SUCCESS)return s;if(i==63)return EFI_NOT_READY;
  }
  for(UINTN i=0;i<600;i++) {
    s=t->ConIn->ReadKeyStroke(t->ConIn,&key);
    if(s==EFI_SUCCESS && key.UnicodeChar=='G')break;
    if(s==EFI_SUCCESS && key.ScanCode==SCAN_ESC)return EFI_ABORTED;
    if(s!=EFI_SUCCESS && s!=EFI_NOT_READY)return s;
    if(i==599)return EFI_TIMEOUT;
    s=t->BootServices->Stall(100000);if(s!=EFI_SUCCESS)return s;
  }
  /* Durable one-shot marker, never overwritten or automatically removed. */
  EFI_FILE_PROTOCOL *marker=NULL;
  s=root->Open(root,&marker,ATTEMPT_PATH,EFI_FILE_MODE_READ,0);
  if(s==EFI_SUCCESS){if(marker)marker->Close(marker);return EFI_ALREADY_STARTED;}
  if(s!=EFI_NOT_FOUND)return s;
  s=root->Open(root,&marker,ATTEMPT_PATH,EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE,0);
  if(s!=EFI_SUCCESS || !marker)return EFI_DEVICE_ERROR;
#if defined(GU_EVGA_AUDIT_NVIDIA)
  char tag[]="Six consumer Stops plus NVIDIA CPU audit armed; no retry\r\n";
#elif defined(GU_EVGA_RELEASE_EDID_SIBLINGS)
  char tag[]="IMG13/16/17 and three EDID Stops armed; no retry\r\n";
#elif defined(GU_EVGA_RELEASE_EDID)
  char tag[]="IMG13/16/17 then physical EDID Stop armed; no retry\r\n";
#elif defined(GU_EVGA_RELEASE_GRAPHICS)
  char tag[]="IMG13/16/17 Stop armed; preserve evidence; no retry\r\n";
#elif defined(GU_EVGA_RELEASE_TEXT)
  char tag[]="IMG13 then IMG16 Stop armed; preserve evidence; no retry\r\n";
#else
  char tag[]="one IMG13 child Stop attempted; preserve evidence; no retry\r\n";
#endif
  UINTN n=sizeof(tag)-1;
  s=marker->Write(marker,&n,tag);if(s==EFI_SUCCESS && n!=sizeof(tag)-1)s=EFI_DEVICE_ERROR;
  if(s==EFI_SUCCESS)s=marker->Flush(marker);
  EFI_STATUS closed=marker->Close(marker);if(s==EFI_SUCCESS)s=closed;if(s!=EFI_SUCCESS)return s;
  s=record(NULL,"evga-text-stop-before",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
  s=Graph(t,FALSE,record);if(s!=EFI_SUCCESS)return s;
  /* Suppress all console calls from this point. No subsequent retry or rollback. */
  *started=TRUE;
  EFI_HANDLE child=Plan.Console;
  s=Plan.Driver->Stop(Plan.Driver,Plan.Virtual,1,&child);
  EFI_STATUS logged=record(NULL,"evga-text-stop-return",s);if(logged!=EFI_SUCCESS)return logged;
  if(s!=EFI_SUCCESS)return s;
  s=Graph(t,TRUE,record);
  logged=record(NULL,"evga-text-stop-post-graph",s);if(logged!=EFI_SUCCESS)return logged;if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_TEXT
  s=Checked(record,"evga-virtual-text-pre-stop",VirtualInterfaces(t,FALSE));if(s!=EFI_SUCCESS)return s;
  s=record(NULL,"evga-virtual-text-stop-before",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
  /* No console/interface calls through the object IMG16 is about to free. */
  s=VirtualDriver->Stop(VirtualDriver,Plan.Virtual,0,NULL);
  logged=record(NULL,"evga-virtual-text-stop-return",s);if(logged!=EFI_SUCCESS)return logged;if(s!=EFI_SUCCESS)return s;
  TextReleased=TRUE;s=Graph(t,TRUE,record);
  s=Checked(record,"evga-virtual-text-post-graph",s);if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_GRAPHICS
  s=record(NULL,"evga-graphics-stop-before",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
  EFI_HANDLE aggregate=Plan.Virtual;
  s=GraphicsDriver->Stop(GraphicsDriver,Plan.Physical,1,&aggregate);
  logged=record(NULL,"evga-graphics-stop-return",s);if(logged!=EFI_SUCCESS)return logged;if(s!=EFI_SUCCESS)return s;
  GraphicsReleased=TRUE;s=Graph(t,TRUE,record);
  s=Checked(record,"evga-graphics-post-graph",s);if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_EDID
  s=record(NULL,"evga-edid-stop-before",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
  s=EdidDriver->Stop(EdidDriver,Plan.Physical,0,NULL);
  logged=record(NULL,"evga-edid-stop-return",s);if(logged!=EFI_SUCCESS)return logged;if(s!=EFI_SUCCESS)return s;
  EdidReleased=TRUE;s=Graph(t,TRUE,record);
  s=Checked(record,"evga-edid-post-graph",s);if(s!=EFI_SUCCESS)return s;
#ifdef GU_EVGA_RELEASE_EDID_SIBLINGS
  UINTN done=0;
  for(UINTN i=0;i<3;i++) {
    if(EdidHandles[i]==Plan.Physical)continue;
    if(done>=2)return EFI_COMPROMISED_DATA;
    s=record(NULL,done?"evga-edid-sibling2-before":"evga-edid-sibling1-before",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
    s=EdidDriver->Stop(EdidDriver,EdidHandles[i],0,NULL);
    logged=record(NULL,done?"evga-edid-sibling2-return":"evga-edid-sibling1-return",s);if(logged!=EFI_SUCCESS)return logged;if(s!=EFI_SUCCESS)return s;
    EdidSiblingReleased[done]=EdidHandles[i];
    s=Graph(t,TRUE,record);
    s=Checked(record,done?"evga-edid-sibling2-post-graph":"evga-edid-sibling1-post-graph",s);if(s!=EFI_SUCCESS)return s;
    done++;
  }
  if(done!=2)return EFI_COMPROMISED_DATA;
#ifdef GU_EVGA_AUDIT_NVIDIA
  s=NvidiaAudit(t,record);if(s!=EFI_SUCCESS)return s;
#endif
#endif
  return EFI_SUCCESS;
#else
  return EFI_SUCCESS;
#endif
#else
  return EFI_SUCCESS;
#endif
#else
  return EFI_SUCCESS;
#endif
}
