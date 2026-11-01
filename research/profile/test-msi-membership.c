/* Developer-only emulator entry. Not a hardware test application. */
#include <Uefi.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/DevicePath.h>
#define GU_DIAGNOSTIC_ONLY
#define GU_DIAGNOSTIC_PROBE
#define GU_PROBE_GENERIC
#define GU_MSI_MEMBERSHIP_AUDIT
#ifdef TEST_MSI_GRAPHICS
#define GU_MSI_ONE_CHILD_TEST
#define GU_MSI_VIRTUAL_TEXT_TEST
#define GU_MSI_GRAPHICS_TEST
#endif
#include "../../internal-boot/boot/msi-runtime-audit.h"
EFI_STATUS EFIAPI efi_main(EFI_SYSTEM_TABLE *t,VOID *base,UINTN size,GU_MSI_RECORD record){
#ifdef TEST_MSI_GRAPHICS
 (void)record;return GuMsiGraphicsPlan(t,base,size,(EFI_HANDLE)0x66660000,NULL);
#else
 return GuMsiMembership(t,base,size,record,NULL);
#endif
}
