/* GPL-2.0-only. Observation-only parser results; never transaction authority. */
#pragma once
#include <Uefi.h>
#include "../unlock/vendor/vbios_610.h"
typedef struct {
  struct gpu_unlock_fwsec Descriptor;
  BOOLEAN PromMatch,Parsed,GeometryMatch,ImageMatch,SignatureMatch;
  UINT8 PromHash[32],ImageHash[32],SignatureHash[32];
} GU_FWSEC_AUDIT;
BOOLEAN GuAuditFwsecGeometry(const struct gpu_unlock_fwsec *f,UINTN bytes);
EFI_STATUS GuAuditCapturedFwsec(const UINT8 *rom,UINTN bytes,GU_FWSEC_AUDIT *out);
