/* Exact MSI captured identity/state admission. CPU only; does not authorize writes. */
#pragma once
#include "checks.h"
#include "sha256.h"
#define GU_MSI_BAR_BASE 0x91000000ULL
#define GU_MSI_PROM_HASH "de78e145e527059faec711a9a320b6dca6a88dc4de0fed882d1688ba2dd1aad1"
static BOOLEAN GuMsiAdmit(const UINT32 cfg[64],UINTN segment,UINTN bus,UINTN device,UINTN function,
 const UINT32 cold[9],const VOID *prom,UINTN promBytes,GU_CAPS *caps){
 GU_CAPS found={0};if(!caps)return FALSE;*caps=found;
 if(!cfg || !cold || !prom || promBytes!=0x100000)return FALSE;
 if(!GuCheckConfigIdentity(cfg,segment,bus,device,function,1,0x220410deU,0x38811462U,&found))return FALSE;
 if((cfg[1]&0xffff)!=2 || cfg[2]!=0x030000a1U || cfg[4]!=GU_MSI_BAR_BASE || cfg[0xc8/4]!=0x00050011U ||
    (cfg[(found.pcie+8)/4]&0x00200000U))return FALSE;
 if(cold[0]!=0xb72000a1U || cold[1]!=0x8b8fU || cold[2]!=0x3ffU || cold[3]!=0x10U || cold[4]!=0 ||
    cold[5]!=0xffffff8fU || cold[6]==0xffffffffU || (cold[6]>>16)==0xbadfU || cold[6]==0x88888888U || cold[7]!=7 || cold[8]!=0x6000U)return FALSE;
 if(!GuHashMatches(prom,promBytes,GU_MSI_PROM_HASH))return FALSE;
 *caps=found;return TRUE;
}
