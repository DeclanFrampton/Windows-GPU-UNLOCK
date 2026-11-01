/* Attended MSI transaction only. All failures require a permanent hold. */
#pragma once
#include "port.h"
typedef EFI_STATUS (*GU_MSI_TRANSACTION_RECORD)(VOID *,const char *,EFI_STATUS);
typedef BOOLEAN (*GU_MSI_TRANSACTION_GRAPH)(EFI_HANDLE,EFI_HANDLE,EFI_PCI_IO_PROTOCOL *);
EFI_STATUS GuMsiTransaction(EFI_SYSTEM_TABLE *table,EFI_HANDLE self,EFI_HANDLE parent,EFI_PCI_IO_PROTOCOL *pci,
 const UINT32 entry[9],const VOID *prom,UINTN promBytes,VOID *payloads[5],GU_MSI_TRANSACTION_GRAPH graph,GU_MSI_TRANSACTION_RECORD record);
