/* GPL-2.0-only. No allocation, callbacks, protocol access or hardware writes. */
#include "stop-transition.h"

static BOOLEAN SameDevice(const GU_DS_DEVICE *a,const GU_DS_DEVICE *b,
                          UINT32 missing,UINT64 cleared) {
  if(a->Handle!=b->Handle || a->Interface!=b->Interface ||
     a->Segment!=b->Segment || a->Bus!=b->Bus || a->Device!=b->Device ||
     a->Function!=b->Function || a->Supported!=b->Supported ||
     b->Attributes!=(a->Attributes&~cleared))return FALSE;
  for(UINTN i=0;i<64;i++)
    if((b->Config[i]|(i==1?missing:0))!=a->Config[i])return FALSE;
  return TRUE;
}

GU_DS_STOP_RESULT GuDsStopTransition(const GU_DS_SNAPSHOT *before,
                                    const GU_DS_SNAPSHOT *after) {
  if(!GuDecodeSnapshotValid(before) || before->Gpu.Attributes!=GU_DS_MEMORY ||
     !after || after->Complete!=TRUE || after->ParentCount!=before->ParentCount)
    return GU_DS_STOP_REFUSED;
  UINT32 missing=before->Gpu.Config[1]&~after->Gpu.Config[1]&2U;
  if(missing && !(before->Gpu.Supported&GU_DS_MEMORY))return GU_DS_STOP_REFUSED;
  if(!SameDevice(&before->Gpu,&after->Gpu,missing,missing?GU_DS_MEMORY:0))
    return GU_DS_STOP_REFUSED;
  for(UINTN i=0;i<before->ParentCount;i++)
    if(!SameDevice(&before->Parents[i],&after->Parents[i],0,0))
      return GU_DS_STOP_REFUSED;
  return missing?GU_DS_STOP_MEMORY_OFF:GU_DS_STOP_UNCHANGED;
}
