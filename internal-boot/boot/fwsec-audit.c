/* GPL-2.0-only. Parse CPU-owned bytes; no EFI services, MMIO or execution. */
#include "fwsec-audit.h"
#include "../unlock/sha256.h"
/* Suppress parser printf diagnostics in this translation unit only. This keeps
 * parsing independent of console/filesystem callbacks. Retain production logic. */
#define GPU_UNLOCK_DIAGNOSTIC_H
#define GU_NOTE(...) ((void)0)
#define GU_ERROR(...) ((void)0)
#define GU_DIAG(value) (value)
#include "../unlock/vendor/vbios_610.c"
static const struct gpu_unlock_fwsec Observed={
  0x45480,0x10300,0,0xf500,0,0,0xf500,0xd80,0xb24,0x1c,9,0x400,2,3,0x45180,768
};
_Static_assert(sizeof(struct gpu_unlock_fwsec)==64,"Descriptor layout must remain explicit");
static BOOLEAN AuditRange(UINTN bytes,UINT32 off,UINT32 n){return off<=bytes && n<=bytes-off;}
BOOLEAN GuAuditFwsecGeometry(const struct gpu_unlock_fwsec *f,UINTN bytes) {
  if(!f || bytes!=0x100000 || !AuditRange(bytes,f->image_off,f->image_size) ||
     !AuditRange(bytes,f->sig_off,f->sig_bytes) || !AuditRange(f->image_size,f->data_off,f->dmem_size) ||
     !AuditRange(f->dmem_size,f->pkc_off,384) || !AuditRange(f->dmem_size,f->interface_off,4))return FALSE;
  const UINT8 *a=(const UINT8 *)f,*b=(const UINT8 *)&Observed;
  for(UINTN i=0;i<sizeof(Observed);i++)if(a[i]!=b[i])return FALSE;
  return TRUE;
}
EFI_STATUS GuAuditCapturedFwsec(const UINT8 *rom,UINTN bytes,GU_FWSEC_AUDIT *out) {
  if(!out)return EFI_INVALID_PARAMETER;
  UINT8 *clear=(UINT8 *)out;for(UINTN i=0;i<sizeof(*out);i++)clear[i]=0;
  if(!rom || bytes!=0x100000)return EFI_INVALID_PARAMETER;
  GuSha256(rom,bytes,out->PromHash);
  out->PromMatch=GuHashMatches(rom,bytes,"accf2a054de0ec394078f933f74356ed7c4057ee0bd1ce6734cacda54ca9e1e1");
  if(!out->PromMatch)return EFI_CRC_ERROR;
  out->Parsed=gpu_unlock_vbios_fwsec(rom,bytes,&out->Descriptor)==0;
  if(!out->Parsed)return EFI_COMPROMISED_DATA;
  out->GeometryMatch=GuAuditFwsecGeometry(&out->Descriptor,bytes);
  if(!out->GeometryMatch)return EFI_COMPROMISED_DATA;
  const struct gpu_unlock_fwsec *f=&out->Descriptor;
  GuSha256(rom+f->image_off,f->image_size,out->ImageHash);
  GuSha256(rom+f->sig_off,f->sig_bytes,out->SignatureHash);
  out->ImageMatch=GuHashMatches(rom+f->image_off,f->image_size,"e604f9be77c4f45d14ccdd2e45caef480801342ec7833e8618c70bbf34c60ab9");
  out->SignatureMatch=GuHashMatches(rom+f->sig_off,f->sig_bytes,"df4953bd74c6c97736ba433a78db9cb27487c78e332445604379dabe7027a4f2");
  return out->ImageMatch && out->SignatureMatch?EFI_SUCCESS:EFI_CRC_ERROR;
}
