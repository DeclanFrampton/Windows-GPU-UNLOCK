/* Emulator-only entry for the actual bounded probe. No NVIDIA callbacks here. */
#include <Uefi.h>
#include <Protocol/PciIo.h>
#include "../../internal-boot/unlock/sha256.h"
typedef EFI_STATUS (*GU_MSI_RECORD)(VOID *,const char *,EFI_STATUS);
#include "../../internal-boot/boot/msi-cold-probe.h"
EFI_STATUS EFIAPI efi_main(EFI_SYSTEM_TABLE *t,VOID *unused,UINTN ignored,GU_MSI_RECORD record){
 (void)unused;(void)ignored;return GuMsiColdProbe(t,(EFI_HANDLE)0x55550000,(EFI_HANDLE)0x88880000,record);
}
