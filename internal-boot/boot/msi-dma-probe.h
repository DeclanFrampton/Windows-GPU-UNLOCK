/* CPU/common-buffer qualification only. No DMA launch or BME enable. */
#pragma once
static EFI_STATUS GuMsiDmaState(EFI_PCI_IO_PROTOCOL *pci){
 UINT32 cfg[16];EFI_STATUS s=GuMsiColdConfig(pci,2,cfg);UINT64 attrs=0;
 if(s!=EFI_SUCCESS)return s;
 s=pci->Attributes(pci,EfiPciIoAttributeOperationGet,0,&attrs);
 UINT64 mask=EFI_PCI_IO_ATTRIBUTE_IO|EFI_PCI_IO_ATTRIBUTE_MEMORY|EFI_PCI_IO_ATTRIBUTE_BUS_MASTER|
  EFI_PCI_IO_ATTRIBUTE_VGA_MEMORY|EFI_PCI_IO_ATTRIBUTE_VGA_IO|EFI_PCI_IO_ATTRIBUTE_VGA_PALETTE_IO;
 return s==EFI_SUCCESS && (attrs&mask)==EFI_PCI_IO_ATTRIBUTE_MEMORY?EFI_SUCCESS:EFI_UNSUPPORTED;
}
static EFI_STATUS GuMsiDmaProbe(EFI_PCI_IO_PROTOCOL *pci,GU_MSI_RECORD record){
 if(!pci->AllocateBuffer || !pci->FreeBuffer || !pci->Map || !pci->Unmap)return EFI_UNSUPPORTED;
 const UINTN pages=EFI_SIZE_TO_PAGES(84277400U),bytes=EFI_PAGES_TO_SIZE(pages);
 EFI_STATUS s=GuMsiDmaState(pci);s=GuMsiColdRecord(record,"msi-dma-state-before",s);if(s!=EFI_SUCCESS)return s;
 VOID *cpu=NULL,*mapping=NULL;EFI_PHYSICAL_ADDRESS device=0;UINTN mapped=bytes;
 s=record(NULL,"msi-dma-allocate-enter",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=pci->AllocateBuffer(pci,AllocateAnyPages,EfiBootServicesData,pages,&cpu,0);
 s=GuMsiColdRecord(record,"msi-dma-allocate-return",s);if(s!=EFI_SUCCESS)return s;
 if(!cpu || ((UINTN)cpu&4095))return EFI_UNSUPPORTED;
 s=record(NULL,"msi-dma-map-enter",EFI_SUCCESS);if(s!=EFI_SUCCESS)return s;
 s=pci->Map(pci,EfiPciIoOperationBusMasterCommonBuffer,cpu,&mapped,&device,&mapping);
 s=GuMsiColdRecord(record,"msi-dma-map-return",s);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-dma-address-value",device);if(s!=EFI_SUCCESS)return s;
 s=record(NULL,"msi-dma-bytes-value",mapped);if(s!=EFI_SUCCESS)return s;
 if(mapped!=bytes || !device || (device&4095) || device>0xffffffffULL || bytes-1>0xffffffffULL-device)return EFI_UNSUPPORTED;
 s=GuMsiDmaState(pci);s=GuMsiColdRecord(record,"msi-dma-state-mapped",s);if(s!=EFI_SUCCESS)return s;
 s=pci->Unmap(pci,mapping);s=GuMsiColdRecord(record,"msi-dma-unmap-return",s);if(s!=EFI_SUCCESS)return s;
 s=pci->FreeBuffer(pci,pages,cpu);s=GuMsiColdRecord(record,"msi-dma-free-return",s);if(s!=EFI_SUCCESS)return s;
 return GuMsiColdRecord(record,"msi-dma-state-after",GuMsiDmaState(pci));
}
