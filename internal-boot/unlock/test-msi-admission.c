/* CPU admission guards; real full-ROM SHA is covered in compiled EFI emulation. */
#define GuHashMatches GuMsiTestHash
#include "msi-admission.h"
static BOOLEAN HashOkay;
BOOLEAN GuMsiTestHash(const VOID *data,UINTN bytes,const char *hash){(void)data;(void)bytes;(void)hash;return HashOkay;}
int main(VOID){
 for(UINTN test=0;test<24;test++){
  UINT32 cfg[64]={0},cold[9]={0xb72000a1,0x8b8f,0x3ff,0x10,0,0xffffff8f,0x70232144,7,0x6000};
  cfg[0]=0x220410de;cfg[1]=0x00100002;cfg[2]=0x030000a1;cfg[3]=0x00800010;cfg[4]=0x91000000;cfg[11]=0x38811462;cfg[13]=0x60;
  cfg[24]=0x48036801;cfg[25]=8;cfg[26]=0x00807805;cfg[30]=0x0012b410;cfg[31]=0x112c8de1;cfg[32]=0x00092930;cfg[45]=0x01140009;cfg[50]=0x00050011;
  UINTN seg=0,bus=1,fn=0,size=0x100000;HashOkay=TRUE;
  switch(test){
   case 1:cold[6]=0x30232144;break;case 2:cfg[0]^=1;break;case 3:cfg[11]=0x33873842;break;
   case 4:cfg[4]=0x84000000;break;case 5:cfg[1]|=4;break;case 6:cfg[2]^=0x01000000;break;
   case 7:cfg[26]|=0x10000;break;case 8:cfg[13]=0x61;break;case 9:cfg[50]^=0x10000;break;
   case 10:cfg[32]|=0x00200000;break;case 11:HashOkay=FALSE;break;case 12:size=512;break;
   case 13:cold[0]^=1;break;case 14:cold[1]^=1;break;case 15:cold[4]=1;break;
   case 16:cold[7]=8;break;case 17:cold[8]=0x3000;break;case 18:cold[6]=0xbadf5620;break;
   case 19:cold[6]=0x88888888;break;case 20:cold[6]=0xffffffff;break;case 21:bus=2;break;case 22:seg=1;break;case 23:fn=1;break;
  }
  GU_CAPS caps={1,1,1,1,1};BOOLEAN ok=GuMsiAdmit(cfg,seg,bus,0,fn,cold,cold,size,&caps);
  if(ok!=(test<2))return 10+(int)test;
  if(ok){if(caps.pm!=0x60 || caps.pcie!=0x78 || caps.msi!=0x68)return 50;}
  else if(caps.pm || caps.pcie || caps.msi || caps.msix || caps.pcie_version)return 51;
 }
 return 0;
}
