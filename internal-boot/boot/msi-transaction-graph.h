/* Verify released MSI graph plus the exact app-owned exclusive claim. */
#pragma once
static EFI_SYSTEM_TABLE *MsiGraphTable;
static EFI_HANDLE MsiGraphSelf,MsiGraphParent,MsiGraphPhysical,MsiGraphVirtual,MsiGraphAgent;
static EFI_STATUS GuMsiSetTransactionGraph(EFI_SYSTEM_TABLE *t,EFI_HANDLE self,EFI_HANDLE parent,EFI_HANDLE physical,EFI_HANDLE virtual,EFI_HANDLE agent){
 if(MsiGraphTable || !t || !self || !parent || !physical || !virtual || !agent)return EFI_ACCESS_DENIED;
 MsiGraphTable=t;MsiGraphSelf=self;MsiGraphParent=parent;MsiGraphPhysical=physical;MsiGraphVirtual=virtual;MsiGraphAgent=agent;return EFI_SUCCESS;
}
static EFI_STATUS MsiSilentRecord(VOID *unused,const char *name,EFI_STATUS value){(void)unused;(void)name;(void)value;return EFI_SUCCESS;}
static BOOLEAN MsiTransactionGraph(EFI_HANDLE parent,EFI_HANDLE self,EFI_PCI_IO_PROTOCOL *pci){
 EFI_BOOT_SERVICES *bs=MsiGraphTable?MsiGraphTable->BootServices:NULL;EFI_GUID pciGuid=EFI_PCI_IO_PROTOCOL_GUID;VOID *fresh=NULL;
 if(!bs || parent!=MsiGraphParent || self!=MsiGraphSelf || !pci || !bs->RaiseTPL || !bs->RestoreTPL)return FALSE;
 EFI_TPL old=bs->RaiseTPL(TPL_NOTIFY);
 EFI_STATUS s=bs->HandleProtocol(parent,&pciGuid,&fresh);if(s==EFI_SUCCESS && fresh!=pci)s=EFI_ACCESS_DENIED;
 if(s==EFI_SUCCESS)s=GuMsiNvParentPost(MsiGraphTable,parent,MsiGraphPhysical,MsiGraphVirtual,MsiGraphAgent,MsiSilentRecord);
 EFI_GUID **protocols=NULL;UINTN count=0,own=0;
 if(s==EFI_SUCCESS)s=bs->ProtocolsPerHandle(parent,&protocols,&count);
 if(s==EFI_SUCCESS && (!protocols || !count || count>256))s=EFI_COMPROMISED_DATA;
 for(UINTN i=0;s==EFI_SUCCESS && i<count;i++){
  EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN n=0;
  if(!protocols[i]){s=EFI_COMPROMISED_DATA;break;}
  s=bs->OpenProtocolInformation(parent,protocols[i],&opens,&n);
  if(s==EFI_SUCCESS && (n>64 || (n && !opens)))s=EFI_COMPROMISED_DATA;
  for(UINTN j=0;s==EFI_SUCCESS && j<n;j++){
   EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=&opens[j];if(e->Attributes==1 || e->Attributes==2 || e->Attributes==4)continue;
   BOOLEAN same=TRUE;for(UINTN k=0;k<sizeof(EFI_GUID);k++)if(((UINT8 *)protocols[i])[k]!=((UINT8 *)&pciGuid)[k])same=FALSE;
   if(same && e->Attributes==EFI_OPEN_PROTOCOL_EXCLUSIVE && e->AgentHandle==self && !e->ControllerHandle && e->OpenCount==1 && !own){own++;continue;}
   s=EFI_ACCESS_DENIED;
  }
  if(opens && bs->FreePool(opens)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
 }
 if(protocols && bs->FreePool(protocols)!=EFI_SUCCESS)s=EFI_DEVICE_ERROR;
 bs->RestoreTPL(old);return s==EFI_SUCCESS && own==1;
}
