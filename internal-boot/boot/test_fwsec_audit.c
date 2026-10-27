/* GPL-2.0-only. RAM-only geometry/error tests; optional private capture input. */
#include "fwsec-audit.h"
#include "../unlock/sha256.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int Checks;
#define CHECK(x) do{Checks++;if(!(x)){fprintf(stderr,"audit check failed line%d\n",__LINE__);return 1;}}while(0)
int main(int argc,char **argv) {
  struct gpu_unlock_fwsec f={0x45480,0x10300,0,0xf500,0,0,0xf500,0xd80,0xb24,0x1c,9,0x400,2,3,0x45180,768};
  CHECK(GuAuditFwsecGeometry(&f,0x100000));
  for(UINTN i=0;i<16;i++){struct gpu_unlock_fwsec bad=f;((UINT32 *)&bad)[i]^=1;CHECK(!GuAuditFwsecGeometry(&bad,0x100000));}
  CHECK(!GuAuditFwsecGeometry(NULL,0x100000));CHECK(!GuAuditFwsecGeometry(&f,0xfffff));
  struct gpu_unlock_fwsec bad=f;bad.image_off=MAX_UINT32;CHECK(!GuAuditFwsecGeometry(&bad,0x100000));
  bad=f;bad.sig_bytes=MAX_UINT32;CHECK(!GuAuditFwsecGeometry(&bad,0x100000));
  UINT8 *rom=calloc(1,0x100000);CHECK(rom!=NULL);GU_FWSEC_AUDIT out;
  CHECK(GuAuditCapturedFwsec(NULL,0x100000,&out)==EFI_INVALID_PARAMETER);
  CHECK(GuAuditCapturedFwsec(rom,512,&out)==EFI_INVALID_PARAMETER);
  CHECK(GuAuditCapturedFwsec(rom,0x100000,NULL)==EFI_INVALID_PARAMETER);
  CHECK(GuAuditCapturedFwsec(rom,0x100000,&out)==EFI_CRC_ERROR && !out.PromMatch && !out.Parsed);
  if(argc==2){
    FILE *file=fopen(argv[1],"rb");CHECK(file!=NULL);CHECK(fread(rom,1,0x100000,file)==0x100000);CHECK(fgetc(file)==EOF);fclose(file);
    UINT8 before[32],after[32];GuSha256(rom,0x100000,before);
    CHECK(GuAuditCapturedFwsec(rom,0x100000,&out)==EFI_SUCCESS && out.PromMatch && out.Parsed && out.GeometryMatch && out.ImageMatch && out.SignatureMatch);
    GuSha256(rom,0x100000,after);CHECK(!memcmp(before,after,32));
    rom[0x45480]^=1;CHECK(GuAuditCapturedFwsec(rom,0x100000,&out)==EFI_CRC_ERROR);
  }
  free(rom);printf("PASS FWSEC RAM audit: %d checks; execution authority absent\n",Checks);return 0;
}
