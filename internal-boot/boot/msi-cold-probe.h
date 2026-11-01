/* Bounded cold-state reads. Normal completion disables memory decode again.
 * Errors hold; never restore speculatively after an unexpected hardware result. */
#pragma once
#include <IndustryStandard/Acpi.h>
static EFI_STATUS GuMsiColdConfig(EFI_PCI_IO_PROTOCOL *pci,UINT16 command,UINT32 cfg[16]){
 EFI_STATUS s=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,16,cfg);
 if(s!=EFI_SUCCESS)return s;
 return cfg[0]==0x220410deU && cfg[11]==0x38811462U && (cfg[2]>>24)==3 && (cfg[1]&0xffff)==command?EFI_SUCCESS:EFI_UNSUPPORTED;
}
static EFI_STATUS GuMsiColdRecord(GU_MSI_RECORD record,const char *name,EFI_STATUS status){
 EFI_STATUS io=record(NULL,name,status);return io==EFI_SUCCESS?status:io;
}
#ifdef GU_MSI_ASSETS_DMA
#include "msi-dma-probe.h"
#endif
static EFI_STATUS GuMsiColdProbe(EFI_SYSTEM_TABLE *t,EFI_HANDLE parent,EFI_HANDLE self,GU_MSI_RECORD record){
 EFI_GUID pciGuid=EFI_PCI_IO_PROTOCOL_GUID;EFI_PCI_IO_PROTOCOL *pci=NULL;
 if(!self)return EFI_INVALID_PARAMETER;
 EFI_STATUS s=t->BootServices->OpenProtocol(parent,&pciGuid,(VOID **)&pci,self,NULL,EFI_OPEN_PROTOCOL_EXCLUSIVE);
 s=GuMsiColdRecord(record,"msi-cold-exclusive-open",s);if(s!=EFI_SUCCESS || !pci)return EFI_UNSUPPORTED;
 if(!pci->Attributes || !pci->Pci.Read || !pci->Mem.Read || !pci->GetBarAttributes)return EFI_UNSUPPORTED;
 UINT32 cfg[16];UINT64 saved=0,now=0;
 s=GuMsiColdConfig(pci,0,cfg);s=GuMsiColdRecord(record,"msi-cold-command-before",s);if(s!=EFI_SUCCESS)return s;
 s=pci->Attributes(pci,EfiPciIoAttributeOperationGet,0,&saved);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-cold-attributes-saved-value",saved);if(s!=EFI_SUCCESS)return s;
 UINT64 forbidden=EFI_PCI_IO_ATTRIBUTE_IO|EFI_PCI_IO_ATTRIBUTE_MEMORY|EFI_PCI_IO_ATTRIBUTE_BUS_MASTER|
  EFI_PCI_IO_ATTRIBUTE_VGA_MEMORY|EFI_PCI_IO_ATTRIBUTE_VGA_IO|EFI_PCI_IO_ATTRIBUTE_VGA_PALETTE_IO;
 if(saved&forbidden)return EFI_UNSUPPORTED;
 EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *bar=NULL;
 s=pci->GetBarAttributes(pci,0,NULL,(VOID **)&bar);if(s!=EFI_SUCCESS || !bar)return EFI_UNSUPPORTED;
 BOOLEAN valid=bar->Desc==ACPI_ADDRESS_SPACE_DESCRIPTOR && bar->Len==sizeof(*bar)-3 && !bar->ResType &&
  (cfg[4]&7)==0 && bar->AddrRangeMin==(cfg[4]&~0xfU) && bar->AddrLen==0x1000000 && !bar->AddrTranslationOffset;
 s=record(NULL,"msi-cold-bar0-base-value",bar->AddrRangeMin);
 if(s==EFI_SUCCESS)s=record(NULL,"msi-cold-bar0-length-value",bar->AddrLen);
 EFI_STATUS freed=t->BootServices->FreePool(bar);if(s!=EFI_SUCCESS)return s;if(freed!=EFI_SUCCESS)return freed;
 s=GuMsiColdRecord(record,"msi-cold-bar0-bounded",valid?EFI_SUCCESS:EFI_UNSUPPORTED);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-cold-memory-enable-enter",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=pci->Attributes(pci,EfiPciIoAttributeOperationEnable,EFI_PCI_IO_ATTRIBUTE_MEMORY,NULL);
 s=GuMsiColdRecord(record,"msi-cold-memory-enable-return",s);if(s!=EFI_SUCCESS)return s;
 s=GuMsiColdConfig(pci,2,cfg);if(s!=EFI_SUCCESS)return s;
 s=pci->Attributes(pci,EfiPciIoAttributeOperationGet,0,&now);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-cold-attributes-enabled-value",now);if(s!=EFI_SUCCESS)return s;
 if(now!=(saved|EFI_PCI_IO_ATTRIBUTE_MEMORY))return EFI_UNSUPPORTED;
 UINT32 chip=0,baselineChip=0;
 s=record(NULL,"msi-cold-chip-before-enter",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=pci->Mem.Read(pci,EfiPciIoWidthUint32,0,0,1,&chip);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-cold-chip-before-value",chip);if(s!=EFI_SUCCESS)return s;
 if(chip!=0xb72000a1U)return EFI_UNSUPPORTED;baselineChip=chip;
 static const UINT32 offsets[]={0x118128,0x118234,0x110100,0x1fa828,0x823804,0x82381c,0x823820,0x1183a4};
 for(UINTN pass=0;pass<2;pass++){
  s=record(NULL,"msi-cold-pass-value",pass);if(s!=EFI_SUCCESS)return s;
  for(UINTN i=0;i<8;i++){
   UINT32 value=0;s=record(NULL,"msi-cold-register-offset-value",offsets[i]);if(s!=EFI_SUCCESS)return s;
   s=pci->Mem.Read(pci,EfiPciIoWidthUint32,0,offsets[i],1,&value);if(s!=EFI_SUCCESS)return s;
   s=record(NULL,"msi-cold-register-value",value);if(s!=EFI_SUCCESS)return s;
   if(value==0xffffffffU || (value>>16)==0xbadfU)return EFI_UNSUPPORTED;
   /* These are observations, not fixed cross-boot or same-boot SS0 pins. */
  }
 }
#if defined(GU_MSI_COLD_FULL_PROM)
 /* Static BSS avoids a 1 MiB firmware stack allocation. No payload execution. */
 static UINT32 prefix[262144];
 const UINTN promWords=262144;
 const char *promHash="de78e145e527059faec711a9a320b6dca6a88dc4de0fed882d1688ba2dd1aad1";
#else
 UINT32 prefix[128];
 const UINTN promWords=128;
 const char *promHash="73ae5e75a576f5dbbf90e7351aac055b7a9b6a249274f7ded03b33c7740d13c8";
#endif
 s=record(NULL,"msi-cold-prom-prefix-enter",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 for(UINTN i=0;i<promWords;i++){
  s=pci->Mem.Read(pci,EfiPciIoWidthUint32,0,0x300000+i*4,1,&prefix[i]);if(s!=EFI_SUCCESS)return s;
 }
 BOOLEAN matched=GuHashMatches(prefix,sizeof(prefix),promHash);
 s=GuMsiColdRecord(record,"msi-cold-prom-prefix-match",matched?EFI_SUCCESS:EFI_UNSUPPORTED);if(s!=EFI_SUCCESS)return s;
 s=pci->Mem.Read(pci,EfiPciIoWidthUint32,0,0,1,&chip);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-cold-chip-after-value",chip);if(s!=EFI_SUCCESS)return s;if(chip!=baselineChip)return EFI_UNSUPPORTED;
#ifdef GU_MSI_ASSETS_DMA
 s=GuMsiDmaProbe(pci,record);if(s!=EFI_SUCCESS)return s;
#endif
 s=record(NULL,"msi-cold-memory-disable-enter",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=pci->Attributes(pci,EfiPciIoAttributeOperationDisable,EFI_PCI_IO_ATTRIBUTE_MEMORY,NULL);
 s=GuMsiColdRecord(record,"msi-cold-memory-disable-return",s);if(s!=EFI_SUCCESS)return s;
 /* No further MMIO after this point. */
 for(UINTN i=0;i<2;i++){
  s=GuMsiColdConfig(pci,0,cfg);if(s!=EFI_SUCCESS)return s;
  s=pci->Attributes(pci,EfiPciIoAttributeOperationGet,0,&now);if(s!=EFI_SUCCESS || now!=saved)return EFI_UNSUPPORTED;
  s=record(NULL,"msi-cold-attributes-restored-value",now);if(s!=EFI_SUCCESS)return s;
 }
 s=record(NULL,"msi-cold-saved-state-restored",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=t->BootServices->CloseProtocol(parent,&pciGuid,self,NULL);
 s=GuMsiColdRecord(record,"msi-cold-exclusive-close",s);if(s!=EFI_SUCCESS)return s;
 EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *opens=NULL;UINTN n=0;
 s=t->BootServices->OpenProtocolInformation(parent,&pciGuid,&opens,&n);if(s!=EFI_SUCCESS)return s;
 BOOLEAN unowned=n<=256 && (!n || opens);
 if(unowned)for(UINTN i=0;i<n;i++)if(opens[i].Attributes&0x38)unowned=FALSE;
 if(opens && t->BootServices->FreePool(opens)!=EFI_SUCCESS)return EFI_DEVICE_ERROR;
 return GuMsiColdRecord(record,"msi-cold-owner-released",unowned?EFI_SUCCESS:EFI_UNSUPPORTED);
}
