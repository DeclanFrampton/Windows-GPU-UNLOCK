/* GPL-2.0-only. RAM fixtures, not captured firmware/hardware evidence. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef NULL
#include "stop-transition.h"

static unsigned Checks;
static GU_DS_SNAPSHOT Before,After,Saved;
static void Check(int ok,const char *label) {
  Checks++;if(!ok){fprintf(stderr,"FAIL %s\n",label);exit(1);}
}
static void Setup(unsigned parents,UINTN segment) {
  memset(&Before,0,sizeof(Before));Before.Complete=TRUE;Before.ParentCount=parents;
  GU_DS_DEVICE *g=&Before.Gpu;
  g->Handle=0x300;g->Interface=0x400;g->Segment=segment;g->Bus=parents;
  g->Config[0]=0x220410de;g->Config[1]=0x00100002;g->Config[2]=0x030000a1;
  g->Config[4]=0xf5000000;g->Config[11]=0x403a1458;
  g->Attributes=GU_DS_MEMORY;g->Supported=0x700;
  for(unsigned i=0;i<parents;i++) {
    GU_DS_DEVICE *p=&Before.Parents[i];
    p->Handle=0x100+i;p->Interface=0x200+i;p->Segment=segment;p->Bus=i;
    p->Config[0]=0x14831022;p->Config[1]=7;p->Config[2]=0x06040000;
    p->Config[3]=0x10000;p->Config[6]=i|((i+1)<<8)|(parents<<16);
    p->Attributes=p->Supported=0x700;
  }
  After=Before;After.Gpu.Config[1]&=~2U;After.Gpu.Attributes=0;Saved=After;
}
static void Refuse(void) {
  Check(GuDsStopTransition(&Before,&After)==GU_DS_STOP_REFUSED,"unsafe transition refused");
}
int main(void) {
  const UINTN segments[]={0,1,0xffff};
  Check(GuDsStopTransition(NULL,NULL)==GU_DS_STOP_REFUSED,"null baseline");
  for(unsigned depth=1;depth<=GU_DS_MAX_PARENTS;depth++)for(unsigned s=0;s<3;s++) {
    Setup(depth,segments[s]);
    Check(GuDecodeSnapshotValid(&Before),"qualified synthetic baseline");
    Check(GuDsStopTransition(&Before,NULL)==GU_DS_STOP_REFUSED,"null observation");
    Check(GuDsStopTransition(&Before,&Before)==GU_DS_STOP_UNCHANGED,"unchanged memory decode");
    Check(GuDsStopTransition(&Before,&After)==GU_DS_STOP_MEMORY_OFF,"only memory lost");
    Check(memcmp(&After,&Saved,sizeof(After))==0,"pure observation stays immutable");
    Check(GuDsStopTransition(&After,&Before)==GU_DS_STOP_REFUSED,"reversed transition");
    for(unsigned node=0;node<=depth;node++)for(unsigned word=0;word<64;word++)
      for(unsigned bit=0;bit<32;bit++) {
        After=Saved;
        GU_DS_DEVICE *d=node?&After.Parents[node-1]:&After.Gpu;
        d->Config[word]^=1U<<bit;
        /* Restoring precisely the missing memory bit is a different coherent
         * observation only if its cache also changes; alone it must fail. */
        Refuse();
      }
    for(unsigned node=0;node<=depth;node++)for(unsigned field=0;field<8;field++)
      for(unsigned bit=0;bit<64;bit++) {
        After=Saved;
        GU_DS_DEVICE *d=node?&After.Parents[node-1]:&After.Gpu;
        UINT64 delta=1ULL<<bit;
        switch(field) {
          case 0:d->Handle^=(UINTN)delta;break;
          case 1:d->Interface^=(UINTN)delta;break;
          case 2:d->Segment^=(UINTN)delta;break;
          case 3:d->Bus^=(UINTN)delta;break;
          case 4:d->Device^=(UINTN)delta;break;
          case 5:d->Function^=(UINTN)delta;break;
          case 6:d->Attributes^=delta;break;
          case 7:d->Supported^=delta;break;
        }
        Refuse();
      }
    After=Saved;After.Complete=2;Refuse();
    After=Saved;After.Complete=FALSE;Refuse();
    After=Saved;After.ParentCount=GU_DS_MAX_PARENTS+1;Refuse();
    After=Saved;After.ParentCount=0;Refuse();
    After=Saved;Before.Gpu.Attributes|=GU_DS_IO;After.Gpu.Attributes=GU_DS_IO;Refuse();
    Before.Gpu.Attributes=GU_DS_MEMORY;Before.Gpu.Supported&=~GU_DS_MEMORY;
    After=Saved;After.Gpu.Supported=Before.Gpu.Supported;Refuse();
    Setup(depth,segments[s]);Before.Complete=2;Refuse();
  }
  printf("PASS stop transition: %u RAM assertions\n",Checks);return 0;
}
