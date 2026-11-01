/* Developer-only emulator entry. Not a hardware test application. */
#include <Uefi.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/DevicePath.h>
#define GU_DIAGNOSTIC_ONLY
#define GU_DIAGNOSTIC_PROBE
#define GU_PROBE_GENERIC
#define GU_MSI_MEMBERSHIP_AUDIT
#include "../../internal-boot/boot/msi-runtime-audit.h"
EFI_STATUS EFIAPI efi_main(EFI_SYSTEM_TABLE *t,VOID *base,UINTN size,GU_MSI_RECORD record){
 return GuMsiMembership(t,base,size,record,NULL);
}
