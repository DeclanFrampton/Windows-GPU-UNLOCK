/* GPL-2.0-only. One IMG13 child Stop; never stop IMG16/17, EDID or NVIDIA. */
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
static EFI_STATUS Code(EFI_BOOT_SERVICES *b,EFI_HANDLE agent,UINTN bytes,UINTN codeBytes,
                       UINTN stop,UINT32 version,const char *hash,EFI_DRIVER_BINDING_PROTOCOL **out,GU_EVGA_RECORD record) {
  EFI_DRIVER_BINDING_PROTOCOL *d=NULL;EFI_LOADED_IMAGE_PROTOCOL *image=NULL;
  EFI_STATUS s=b->HandleProtocol(agent,&Binding,(VOID **)&d);
  if(s==EFI_SUCCESS && d){s=Value(record,"evga-observed-binding-version",d->Version);if(s!=EFI_SUCCESS)return s;}
  if(s!=EFI_SUCCESS || !d || d->DriverBindingHandle!=agent || !d->ImageHandle || !d->Stop || d->Version!=version)return Checked(record,"evga-code-binding",EFI_UNSUPPORTED);
  s=b->HandleProtocol(d->ImageHandle,&Loaded,(VOID **)&image);
  if(s==EFI_SUCCESS && image){s=Value(record,"evga-observed-image-bytes",image->ImageSize);if(s!=EFI_SUCCESS)return s;}
  if(s!=EFI_SUCCESS || !image || !image->ImageBase || image->ImageSize!=bytes || bytes<=0x2a0 || codeBytes>bytes-0x2a0)return Checked(record,"evga-code-loaded-image",EFI_UNSUPPORTED);
  UINTN base=(UINTN)image->ImageBase;
  if((UINTN)d->Stop>=base){s=Value(record,"evga-observed-stop-rva",(UINTN)d->Stop-base);if(s!=EFI_SUCCESS)return s;}
  if(base>~(UINTN)0-bytes || (UINTN)d->Stop!=base+stop || stop<0x2a0 || stop-0x2a0>=codeBytes)return Checked(record,"evga-code-stop-address",EFI_UNSUPPORTED);
  if(!GuHashMatches((UINT8 *)image->ImageBase+0x2a0,codeBytes,hash))return Checked(record,"evga-code-section-hash",EFI_CRC_ERROR);
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
    if((cfg[2]>>24)==3){displays++;if(cfg[0]==0x220410deU && cfg[11]==0x33873842U)matches++;}
  }
  if(b->FreePool(handles)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
  EFI_STATUS io=Value(record,"evga-observed-display-count",displays);if(io!=EFI_SUCCESS)return io;
  io=Value(record,"evga-observed-matching-card-count",matches);if(io!=EFI_SUCCESS)return io;
  return s==EFI_SUCCESS && displays==1 && matches==1?EFI_SUCCESS:EFI_UNSUPPORTED;
}
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
  VOID *text=NULL,*gop=NULL;
  if(b->HandleProtocol(virtual,&Text,&text)!=EFI_SUCCESS || !text ||
     b->HandleProtocol(t->ConsoleOutHandle,&Text,&text)!=EFI_SUCCESS || !text ||
     b->HandleProtocol(t->ConsoleOutHandle,&Gop,&gop)!=EFI_UNSUPPORTED)return Checked(record,"evga-console-interfaces",EFI_UNSUPPORTED);
  if(Plan.Physical && (Plan.Physical!=physical || Plan.Virtual!=virtual || Plan.Console!=t->ConsoleOutHandle))return EFI_ACCESS_DENIED;
  Plan.Physical=physical;Plan.Virtual=virtual;Plan.Console=t->ConsoleOutHandle;
  s=Checked(record,"evga-gfx-edges",Edges(b,physical,&Gop,virtual,TRUE,&Plan.Gfx,FALSE));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-virtual-text-edges",Edges(b,virtual,&Gop,NULL,FALSE,&Plan.VirtualText,FALSE));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-text-splitter-edges",Edges(b,virtual,&Text,Plan.Console,TRUE,&Plan.TextAgent,after));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-gfx-code",Code(b,Plan.Gfx,0x2180,0x1990,0x88c,17,"3f4c4ea26023ddf00990b59385d0fcf3139acb583c70406828777cdceab8cecb",NULL,record));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-virtual-text-code",Code(b,Plan.VirtualText,0x3bc0,0x1e00,0xb2c,16,"e5e68f0856c6e932da9bf3c680bac955dbf180eb083da78b64007388d89e24a7",NULL,record));if(s!=EFI_SUCCESS)return s;
  return Checked(record,"evga-text-splitter-code",Code(b,Plan.TextAgent,0x6ae0,0x5620,0x104c,16,"e2b072199726ae784f749057c3c5453ed8db0bb3fbe1a73ccca7e6f302325291",&Plan.Driver,record));
}
EFI_STATUS GuEvgaTextStopVerify(EFI_SYSTEM_TABLE *t) {
  if(!t || !t->BootServices || !Plan.Driver || !Plan.TextAgent)return EFI_INVALID_PARAMETER;
  return Graph(t,TRUE,NULL); /* Files are closed: no logging on the final check. */
}
EFI_STATUS GuEvgaTextStop(EFI_SYSTEM_TABLE *t,EFI_FILE_PROTOCOL *root,GU_EVGA_RECORD record,BOOLEAN *started) {
  if(!t || !t->BootServices || !t->ConIn || !root || !record || !started)return EFI_INVALID_PARAMETER;
  *started=FALSE;EFI_STATUS s=Checked(record,"evga-pci-inventory",Inventory(t->BootServices,record));if(s!=EFI_SUCCESS)return s;
  s=Checked(record,"evga-initial-graph",Graph(t,FALSE,record));if(s!=EFI_SUCCESS)return s;
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
  s=root->Open(root,&marker,L"\\RTX3090-UNLOCK\\EVGA-TEXT-STOP.ARMED",EFI_FILE_MODE_READ,0);
  if(s==EFI_SUCCESS){if(marker)marker->Close(marker);return EFI_ALREADY_STARTED;}
  if(s!=EFI_NOT_FOUND)return s;
  s=root->Open(root,&marker,L"\\RTX3090-UNLOCK\\EVGA-TEXT-STOP.ARMED",EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE,0);
  if(s!=EFI_SUCCESS || !marker)return EFI_DEVICE_ERROR;
  char tag[]="one IMG13 child Stop attempted; preserve evidence; no retry\r\n";UINTN n=sizeof(tag)-1;
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
  logged=record(NULL,"evga-text-stop-post-graph",s);return logged==EFI_SUCCESS?s:logged;
}
