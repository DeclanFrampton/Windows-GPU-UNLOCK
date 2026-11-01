/* Exact MSI EDID ownership and NVIDIA metadata only. No NVIDIA method calls. */
#pragma once
#include <Protocol/EdidDiscovered.h>
#include <Protocol/PciIo.h>
static EFI_STATUS GuMsiEdidState(EFI_SYSTEM_TABLE *t,EFI_HANDLE physical,EFI_HANDLE agent,BOOLEAN present){
 EFI_GUID edid=EFI_EDID_DISCOVERED_PROTOCOL_GUID;EFI_HANDLE *handles=NULL;UINTN n=0;
 EFI_STATUS s=t->BootServices->LocateHandleBuffer(ByProtocol,&edid,NULL,&n,&handles);
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN ok=handles && n==1 && handles[0]==physical;
 if(handles && t->BootServices->FreePool(handles)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!ok)return EFI_UNSUPPORTED;
 EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN opened=0,owners=0;
 s=t->BootServices->OpenProtocolInformation(physical,&edid,&opens,&opened);if(s!=EFI_SUCCESS)return s;
 ok=opened<=256 && (!opened || opens);
 if(ok)for(UINTN i=0;i<opened;i++)if(opens[i].Attributes&0x18){
  if(opens[i].AgentHandle!=agent || opens[i].Attributes!=0x10 || opens[i].ControllerHandle!=physical || opens[i].OpenCount!=1)ok=FALSE;
  owners++;
 }
 if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return ok && owners==(present?1U:0U)?EFI_SUCCESS:EFI_UNSUPPORTED;
}
static EFI_STATUS GuMsiNvidiaAudit(EFI_SYSTEM_TABLE *t,EFI_HANDLE physical,EFI_HANDLE agent){
 EFI_GUID path=EFI_DEVICE_PATH_PROTOCOL_GUID,pci=EFI_PCI_IO_PROTOCOL_GUID;
 EFI_HANDLE *handles=NULL,parent=NULL;UINTN n=0,children=0;
 EFI_STATUS s=t->BootServices->LocateHandleBuffer(ByProtocol,&path,NULL,&n,&handles);
 if(s!=EFI_SUCCESS)return s;
 BOOLEAN ok=handles && n && n<=512;
 if(ok)for(UINTN i=0;i<n;i++){
  EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN opened=0;
  s=t->BootServices->OpenProtocolInformation(handles[i],&path,&opens,&opened);
  if(s!=EFI_SUCCESS || opened>256 || (opened && !opens))ok=FALSE;
  if(ok)for(UINTN j=0;j<opened;j++)if(opens[j].AgentHandle==agent && (opens[j].Attributes&8)){
   if(opens[j].Attributes!=8 || opens[j].ControllerHandle!=physical || opens[j].OpenCount!=1)ok=FALSE;
   children++;parent=handles[i];
  }
  if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)ok=FALSE;
  if(!ok)break;
 }
 if(handles && t->BootServices->FreePool(handles)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!ok || children!=1 || !parent || parent==physical)return EFI_UNSUPPORTED;
 EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN opened=0,owners=0;
 s=t->BootServices->OpenProtocolInformation(parent,&pci,&opens,&opened);if(s!=EFI_SUCCESS)return s;
 ok=opened<=256 && (!opened || opens);
 if(ok)for(UINTN i=0;i<opened;i++)if(opens[i].Attributes&0x18){
  if(opens[i].AgentHandle!=agent || opens[i].Attributes!=0x10 || opens[i].ControllerHandle!=parent || opens[i].OpenCount!=1)ok=FALSE;
  owners++;
 }
 if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return ok && owners==1?EFI_SUCCESS:EFI_UNSUPPORTED;
}
