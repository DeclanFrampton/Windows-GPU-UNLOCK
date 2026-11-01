/* Emulator-only wrapper for the actual admission helpers. */
#include <Uefi.h>
#include <Protocol/DevicePath.h>
#include "../../internal-boot/boot/msi-edid-audit.h"
EFI_STATUS EFIAPI efi_main(EFI_SYSTEM_TABLE *t,EFI_HANDLE physical,EFI_HANDLE agent,BOOLEAN present){
#ifdef TEST_NVIDIA_METADATA
 (void)present;return GuMsiNvidiaAudit(t,physical,agent);
#else
 return GuMsiEdidState(t,physical,agent,present);
#endif
}
