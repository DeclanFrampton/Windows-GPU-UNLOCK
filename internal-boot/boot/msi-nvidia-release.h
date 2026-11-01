/* Exact GOP child/parent release checks. No unlock transaction or rollback. */
#pragma once
#ifndef GU_MSI_EDID_TEST
#error NVIDIA release requires the prior consumer sequence
#endif
static EFI_GUID GuMsiNvPrivate={0xfe47349a,0x7f0d,0x4641,{0x82,0x2b,0x34,0xba,0xa2,0x8e,0xcd,0xd0}};
static EFI_STATUS GuMsiNvPrivateState(EFI_SYSTEM_TABLE *t,EFI_HANDLE parent,EFI_HANDLE child){
 VOID *context=NULL;UINTN words[4];
 EFI_STATUS s=t->BootServices->HandleProtocol(parent,&GuMsiNvPrivate,&context);
 if(s!=EFI_SUCCESS || !context || (UINTN)context>~(UINTN)0-0xa0)return EFI_UNSUPPORTED;
 s=GuMsiReadWords(t,(UINTN)context+0x80,words);
 return s==EFI_SUCCESS && words[1]==(UINTN)child && (words[3]&0xff)==0?EFI_SUCCESS:EFI_UNSUPPORTED;
}
static EFI_STATUS GuMsiNvOwner(EFI_SYSTEM_TABLE *t,EFI_HANDLE parent,EFI_HANDLE agent,BOOLEAN present){
 EFI_GUID pci=EFI_PCI_IO_PROTOCOL_GUID,path=EFI_DEVICE_PATH_PROTOCOL_GUID;
 for(UINTN pass=0;pass<2;pass++){
  EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN n=0,owners=0;
  EFI_STATUS s=t->BootServices->OpenProtocolInformation(parent,pass?&path:&pci,&opens,&n);if(s!=EFI_SUCCESS)return s;
  BOOLEAN ok=n<=256 && (!n || opens);
  if(ok)for(UINTN i=0;i<n;i++)if(opens[i].Attributes&0x18){
   if(pass || opens[i].AgentHandle!=agent || opens[i].Attributes!=0x10 || opens[i].ControllerHandle!=parent || opens[i].OpenCount!=1)ok=FALSE;
   owners++;
  }
  if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
  if(!ok || owners!=(!pass && present?1U:0U))return EFI_UNSUPPORTED;
 }
 return EFI_SUCCESS;
}
static EFI_STATUS GuMsiNvConsolePost(EFI_SYSTEM_TABLE *t,EFI_HANDLE physical,EFI_HANDLE virtual){
 EFI_GUID gop=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,edid=EFI_EDID_DISCOVERED_PROTOCOL_GUID;
 EFI_HANDLE *handles=NULL;UINTN n=0;
 EFI_STATUS s=t->BootServices->LocateHandleBuffer(ByProtocol,&gop,NULL,&n,&handles);
 BOOLEAN ok=s==EFI_SUCCESS && handles && n==1 && handles[0]==virtual;
 if(handles && t->BootServices->FreePool(handles)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!ok)return EFI_UNSUPPORTED;
 EFI_GRAPHICS_OUTPUT_PROTOCOL *g=NULL;
 s=t->BootServices->HandleProtocol(virtual,&gop,(VOID **)&g);
 if(s!=EFI_SUCCESS || !g || !g->Mode || g->Mode->FrameBufferBase || g->Mode->FrameBufferSize)return EFI_UNSUPPORTED;
 handles=NULL;n=0;s=t->BootServices->LocateHandleBuffer(ByProtocol,&edid,NULL,&n,&handles);
 ok=s==EFI_NOT_FOUND && !n && !handles;
 if(handles && t->BootServices->FreePool(handles)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!ok)return EFI_UNSUPPORTED;
 handles=NULL;n=0;s=t->BootServices->LocateHandleBuffer(AllHandles,NULL,NULL,&n,&handles);
 ok=s==EFI_SUCCESS && handles && n && n<=4096;
 if(ok)for(UINTN i=0;i<n;i++)if(handles[i]==physical)ok=FALSE;
 if(handles && t->BootServices->FreePool(handles)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!ok)return EFI_UNSUPPORTED;
 return GuMsiVirtualInterfaces(t,virtual);
}
static EFI_STATUS GuMsiNvChildrenPost(EFI_SYSTEM_TABLE *t,EFI_HANDLE parent,EFI_HANDLE physical,EFI_HANDLE virtual,EFI_HANDLE agent){
 EFI_STATUS s=GuMsiNvConsolePost(t,physical,virtual);if(s!=EFI_SUCCESS)return s;
 s=GuMsiNvOwner(t,parent,agent,TRUE);if(s!=EFI_SUCCESS)return s;
 return GuMsiNvPrivateState(t,parent,NULL);
}
static EFI_STATUS GuMsiNvParentPost(EFI_SYSTEM_TABLE *t,EFI_HANDLE parent,EFI_HANDLE physical,EFI_HANDLE virtual,EFI_HANDLE agent,GU_MSI_RECORD record){
 EFI_STATUS s=GuMsiNvConsolePost(t,physical,virtual);if(s!=EFI_SUCCESS)return s;
 EFI_GUID **list=NULL;UINTN n=0;
 s=t->BootServices->ProtocolsPerHandle(parent,&list,&n);
 BOOLEAN absent=s==EFI_SUCCESS && list && n<=256;
 if(absent)for(UINTN i=0;i<n;i++){
  if(!list[i]){absent=FALSE;break;}
  BOOLEAN same=TRUE;for(UINTN j=0;j<sizeof(EFI_GUID);j++)if(((UINT8 *)list[i])[j]!=((UINT8 *)&GuMsiNvPrivate)[j])same=FALSE;
  if(same)absent=FALSE;
 }
 if(list && t->BootServices->FreePool(list)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 if(!absent)return EFI_UNSUPPORTED;
 s=GuMsiNvOwner(t,parent,agent,FALSE);if(s!=EFI_SUCCESS)return s;
 EFI_GUID pciGuid=EFI_PCI_IO_PROTOCOL_GUID;EFI_PCI_IO_PROTOCOL *pci=NULL;UINT32 cfg[16];
 s=t->BootServices->HandleProtocol(parent,&pciGuid,(VOID **)&pci);if(s!=EFI_SUCCESS || !pci)return EFI_UNSUPPORTED;
 s=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,16,cfg);if(s!=EFI_SUCCESS)return s;
 if(cfg[0]!=0x220410deU || cfg[11]!=0x38811462U || (cfg[2]>>24)!=3)return EFI_UNSUPPORTED;
 /* This event stores data in the status field, not an operation result. */
 return record(NULL,"msi-nvidia-pci-command-value",(EFI_STATUS)(cfg[1]&0xffff));
}
