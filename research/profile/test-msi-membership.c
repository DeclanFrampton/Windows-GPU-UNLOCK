/* Developer-only emulator entry. Not a hardware test application. */
#include <Uefi.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/DevicePath.h>
#define GU_DIAGNOSTIC_ONLY
#define GU_DIAGNOSTIC_PROBE
#define GU_PROBE_GENERIC
#define GU_MSI_MEMBERSHIP_AUDIT
#if defined(TEST_MSI_GRAPHICS) || defined(TEST_MSI_NVIDIA_PRIVATE)
#define GU_MSI_ONE_CHILD_TEST
#define GU_MSI_VIRTUAL_TEXT_TEST
#define GU_MSI_GRAPHICS_TEST
#endif
#ifdef TEST_MSI_NVIDIA_PRIVATE
#define GU_MSI_EDID_TEST
#define GU_MSI_NVIDIA_RELEASE
#endif
#include "../../internal-boot/boot/msi-runtime-audit.h"
EFI_STATUS EFIAPI efi_main(EFI_SYSTEM_TABLE *t,VOID *base,UINTN size,GU_MSI_RECORD record){
#ifdef TEST_MSI_NVIDIA_PRIVATE
 (void)base;(void)size;(void)record;return GuMsiNvPrivateState(t,(EFI_HANDLE)0x55550000,(EFI_HANDLE)0x66660000);
#elif defined(TEST_MSI_GRAPHICS)
 (void)record;return GuMsiGraphicsPlan(t,base,size,(EFI_HANDLE)0x66660000,NULL);
#else
 return GuMsiMembership(t,base,size,record,NULL);
#endif
}
