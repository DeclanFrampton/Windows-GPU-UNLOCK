/* Emulator-only wrapper for the actual admission helpers. */
#include <Uefi.h>
#include <Protocol/DevicePath.h>
#ifdef TEST_NVIDIA_OWNER
#include <Protocol/LoadedImage.h>
#define GU_DIAGNOSTIC_ONLY
#define GU_DIAGNOSTIC_PROBE
#define GU_PROBE_GENERIC
#define GU_MSI_MEMBERSHIP_AUDIT
#define GU_MSI_ONE_CHILD_TEST
#define GU_MSI_VIRTUAL_TEXT_TEST
#define GU_MSI_GRAPHICS_TEST
#define GU_MSI_EDID_TEST
#define GU_MSI_NVIDIA_RELEASE
#include "../../internal-boot/boot/msi-runtime-audit.h"
#else
#include "../../internal-boot/boot/msi-edid-audit.h"
#endif
EFI_STATUS EFIAPI efi_main(EFI_SYSTEM_TABLE *t,EFI_HANDLE physical,EFI_HANDLE agent,BOOLEAN present){
#ifdef TEST_NVIDIA_OWNER
 return GuMsiNvOwner(t,physical,agent,present);
#elif defined(TEST_NVIDIA_METADATA)
 (void)present;return GuMsiNvidiaAudit(t,physical,agent,NULL);
#else
 return GuMsiEdidState(t,physical,agent,present);
#endif
}
