/* GPL-2.0-only. Actual prepare/release/claim/restore code; synthetic RAM devices. */
static void AuditConsoleSetup(void);
static void AuditFullSetup(void);
#define GU_RELEASE_AUDIT_TEST_CONSOLE_SETUP AuditConsoleSetup
#define GU_RELEASE_AUDIT_TEST_FULL_SETUP AuditFullSetup
#include "test_full.c"

static EFI_PCI_IO_PROTOCOL ParentIo;
static UINT32 ParentConfig[64];
static UINT8 ControllerPath[28],ParentPath[22];
static unsigned ParentReads,FaultRead,ReadBudget,ReentryChecks;
static BOOLEAN Reenter;
static BOOLEAN ModelMismatch;
static UINT64 AfterOverride;
static unsigned CallbackFaultAt,CallbackFaultKind,FirstOwnedRead,PreEnableRead,NvPreflightRead;
static UINTN FirstOwnedCapture;
static BOOLEAN Injected;
#define PARENT_HANDLE ((EFI_HANDLE)(UINTN)50001)
static EFI_STATUS EFIAPI AuditHandle(EFI_HANDLE h,EFI_GUID *g,VOID **out) {
  if(h==PARENT_HANDLE) {
    if(GuGuidEqual(g,&PciGuid)){*out=&ParentIo;return EFI_SUCCESS;}
    if(GuGuidEqual(g,&PathGuid)){*out=ParentPath;return EFI_SUCCESS;}
  }
  if(h==FX_RtxPci && GuGuidEqual(g,&PathGuid)){*out=ControllerPath;return EFI_SUCCESS;}
  return Handle(h,g,out);
}
static EFI_STATUS EFIAPI AuditFind(EFI_GUID *g,EFI_DEVICE_PATH_PROTOCOL **rest,EFI_HANDLE *h) {
  Check(GuGuidEqual(g,&PciGuid),"only PCI path resolution");
  const UINT8 *p=(const VOID *)*rest;
  if(!memcmp(p,ParentPath,18)) {
    UINTN body=p[18]==0x7f?18:24;*h=body==18?PARENT_HANDLE:FX_RtxPci;
    *rest=(VOID *)(p+body);return EFI_SUCCESS;
  }
  return FindPci(g,rest,h);
}
static EFI_STATUS EFIAPI AuditLocation(EFI_PCI_IO_PROTOCOL *io,UINTN *s,UINTN *b,UINTN *d,UINTN *f) {
  if(io==&ParentIo){*s=GU_TARGET_SEGMENT;*b=0;*d=ParentPath[17];*f=ParentPath[16];return EFI_SUCCESS;}
  return Location(io,s,b,d,f);
}
static EFI_STATUS EFIAPI AuditRead(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_WIDTH w,UINT32 offset,UINTN n,VOID *out) {
  if(Reenter) {
    unsigned reads=ParentReads;
    Check(GuPrepareConsole(LastTable,Log,NULL)==EFI_ALREADY_STARTED,"nested prepare cannot reset history or plan");
    Check(GuReleaseGop(LastTable,(VOID *)9999,FullLog,NULL)==EFI_ALREADY_STARTED,"nested release cannot reset Full");
    Check(reads==ParentReads,"nested entries issue no read");ReentryChecks++;
  }
  if(io!=&ParentIo)return ExtraRead(io,w,offset,n,out);
  Check(w==EfiPciIoWidthUint32 && !offset && n==64,"bounded parent full read only");
  ParentReads++;
  if(FullMode && Phase==2 && !NvPreflightRead)NvPreflightRead=ParentReads;
  if(Full.Owned) {
    if(!FirstOwnedRead){FirstOwnedRead=ParentReads;FirstOwnedCapture=ReleaseAudit.Next;}
    else if(ReleaseAudit.Next!=FirstOwnedCapture && !PreEnableRead)PreEnableRead=ParentReads;
  }
  if(ParentReads==CallbackFaultAt) {
    Injected=TRUE;
    switch(CallbackFaultKind) {
    case 1:LastTable->BootServices->DisconnectController=NULL;break;
    case 2:LastTable->BootServices->OpenProtocol=NULL;break;
    case 3:LastTable->BootServices->CloseProtocol=NULL;break;
    case 4:LastTable->BootServices->RaiseTPL=NULL;break;
    case 5:LastTable->BootServices->RestoreTPL=NULL;break;
    case 6:Live.Edges[Live.Count++]=(EDGE){FX_RtxPci,FX_NvAgent,FX_Input,PathGuid,8,1};break;
    case 7:NvBinding.Version++;break;
    case 8:Check(Full.Owned,"claim loss injected only under our claim");Drop(FX_RtxPci,(VOID *)9999,&PciGuid);break;
    default:Check(FALSE,"known fault");
    }
  }
  if(ParentReads<=2)Check(!Calls,"original parent baseline precedes every console Disconnect");
  memcpy(out,ParentConfig,sizeof(ParentConfig));
  if(ParentReads==FaultRead)((UINT32 *)out)[63]^=1;
  return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI AuditAttributes(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_ATTRIBUTE_OPERATION op,UINT64 mask,UINT64 *out) {
  if(io!=&ParentIo) {
    if(op==EfiPciIoAttributeOperationEnable)Check(mask==EFI_PCI_IO_ATTRIBUTE_MEMORY,"only MEMORY restored");
    EFI_STATUS s=Attributes(io,op,mask,out);
    if(s==EFI_SUCCESS && op==EfiPciIoAttributeOperationGet && Phase==4 && !EnableCalls && AfterOverride)*out=AfterOverride;
    return s;
  }
  Check(!mask && out && (op==EfiPciIoAttributeOperationGet || op==EfiPciIoAttributeOperationSupported),"parent is read-only");
  *out=op==EfiPciIoAttributeOperationGet?GU_DS_MEMORY:GU_DS_IO|GU_DS_MEMORY|GU_DS_MASTER;
  return EFI_SUCCESS;
}
static void AuditConsoleSetup(void) {
  Check(sizeof(TestRtxPath)==36,"two PCI nodes in this synthetic fixture");
  memcpy(ControllerPath,TestRtxPath,24);memcpy(ControllerPath+24,"\x7f\xff\x04\x00",4);
  memcpy(ParentPath,TestRtxPath,18);memcpy(ParentPath+18,"\x7f\xff\x04\x00",4);
  memset(ParentConfig,0,sizeof(ParentConfig));ParentConfig[0]=0x14831022;ParentConfig[1]=2;
  ParentConfig[2]=0x06040000;ParentConfig[3]=0x00010000;ParentConfig[6]=(GU_TARGET_BUS<<16)|(GU_TARGET_BUS<<8);
  ParentIo=(EFI_PCI_IO_PROTOCOL){0};ParentIo.GetLocation=AuditLocation;ParentIo.Pci.Read=AuditRead;ParentIo.Attributes=AuditAttributes;
  memcpy(MockConfig,InitialFullConfig,sizeof(MockConfig));MockAttributes=ModelMismatch?GU_DS_IO|GU_DS_MEMORY:GU_DS_MEMORY;
  RtxPci.GetLocation=AuditLocation;RtxPci.Pci.Read=AuditRead;RtxPci.Attributes=AuditAttributes;
  LastTable->BootServices->HandleProtocol=AuditHandle;LastTable->BootServices->LocateDevicePath=AuditFind;
  LastTable->BootServices->OpenProtocol=Open;LastTable->BootServices->CloseProtocol=Close;
}
static void AuditFullSetup(void) {
  RtxPci.Attributes=AuditAttributes;
  if(ModelMismatch)MockAttributes=GU_DS_IO|GU_DS_MEMORY;
}
static EFI_STATUS AuditedRun(unsigned fault,BOOLEAN reenter) {
  /* Each test models a new image. Production has no reset or retry API. */
  ReleaseAudit=(GU_RELEASE_AUDIT_STATE){0};ParentReads=0;FaultRead=fault;Reenter=reenter;Full.Owned=FALSE;
  Injected=FALSE;FirstOwnedRead=PreEnableRead=NvPreflightRead=0;FirstOwnedCapture=0;
  return RunFull(0);
}
int main(int argc,char **argv) {
  Check(argc==4,"synthetic loaded nvgop, PROM and config required");
  FILE *f=fopen(argv[1],"rb");Check(f && fread(NvMemory,1,sizeof(NvMemory),f)==sizeof(NvMemory),"loaded synthetic driver");fclose(f);
  f=fopen(argv[2],"rb");Check(f && fread(PromMemory,1,sizeof(PromMemory),f)==sizeof(PromMemory),"synthetic PROM");fclose(f);
  f=fopen(argv[3],"rb");Check(f && fread(InitialFullConfig,1,sizeof(InitialFullConfig),f)==sizeof(InitialFullConfig),"synthetic config");fclose(f);
  Check(AuditedRun(0,FALSE)==EFI_SUCCESS,"actual console, NVIDIA Stop, claim, MEMORY restore and final verify succeed");
  Check(EnableCalls==1 && ClaimCalls==1 && CloseCalls==1 && ReleaseAudit.Ready && ReleaseAudit.ReleaseUsed,"real phase integration reached");
  ReadBudget=ParentReads;
  for(unsigned fault=1;fault<=ReadBudget;fault++) {
    Check(AuditedRun(fault,FALSE)!=EFI_SUCCESS,"parent read drift at every boundary blocks completion");
    Check(ParentReads==fault || ParentReads==fault+1,"injected parent fault actually reached");
    Check(!Full.Owned,"no retained claim after observation refusal");
  }
  Check(AuditedRun(0,TRUE)==EFI_SUCCESS && ReentryChecks,"nested prepare/release refused through real callbacks");
  Check(GuReleaseGop(LastTable,(VOID *)9999,FullLog,NULL)==EFI_ALREADY_STARTED,"completed release cannot be retried");
  Check(GuPrepareConsole(LastTable,Log,NULL)==EFI_ALREADY_STARTED,"completed preparation cannot reset history");
#ifdef GU_RELEASE_MISMATCH_RESEARCH
  ModelMismatch=TRUE;
  Check(AuditedRun(0,FALSE)==EFI_SUCCESS,"actual cache300 -> Stop raw0/cache0 -> MEMORY-only cache200 path");
  Check(ReleaseAudit.Mismatch && ReleaseAudit.PlanReady && Full.Attributes==(GU_DS_IO|GU_DS_MEMORY) &&
    Full.TargetAttributes==GU_DS_MEMORY && MockAttributes==GU_DS_MEMORY,"actual Before300 retained separately from planned target200");
  const GU_DS_SNAPSHOT *after=&ReleaseAudit.Captures[ReleaseAudit.ActualAfterIndex].Snapshot;
  Check(after->Gpu.Attributes==0 && !(after->Gpu.Config[1]&0xffffU) &&
    ReleaseAudit.Captures[0].Snapshot.Gpu.Attributes==(GU_DS_IO|GU_DS_MEMORY),"actual observations are not rewritten as targets");
  Check(EnableCalls==1 && ClaimCalls==1 && CloseCalls==1,"single bounded restore with closed claim");
  unsigned firstOwned=FirstOwnedRead,preEnable=PreEnableRead,preNv=NvPreflightRead;
  Check(firstOwned && preEnable>firstOwned && preNv,"sensitive actual phases observed");
  for(unsigned fault=1;fault<=ReadBudget;fault++) {
    Check(AuditedRun(fault,FALSE)!=EFI_SUCCESS,"mismatch parent drift refuses before completion");
    Check(!Full.Owned,"mismatch fault leaves no claim");
  }
  for(UINT64 attrs=GU_DS_IO;attrs<=(GU_DS_IO|GU_DS_MEMORY);attrs+=GU_DS_IO) {
    AfterOverride=attrs;
    Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && !EnableCalls,"raw0 with cache100/200/300 never grants MEMORY restore");
  }
  AfterOverride=0;
  for(unsigned kind=1;kind<=5;kind++)for(unsigned at=1;at<=ReadBudget;at++) {
    CallbackFaultAt=at;CallbackFaultKind=kind;
    Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && Injected,"effect dispatch drift at each audit boundary refuses");
    Check(!Full.Owned,"frozen cleanup closes our claim despite changed live dispatch");
  }
  const unsigned sensitive[]={firstOwned,preEnable};
  for(unsigned i=0;i<2;i++)for(unsigned kind=6;kind<=8;kind+=2) {
    CallbackFaultAt=sensitive[i];CallbackFaultKind=kind;
    Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && Injected && !EnableCalls,"foreign graph/claim loss in audit stops before Enable");
    Check(!Full.Owned,"failure cleanup completes");
  }
  CallbackFaultAt=preNv;CallbackFaultKind=7;
  Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && Injected && !EnableCalls && Calls==2,
    "audit driver-binding mutation caught before NVIDIA Stop");
  CallbackFaultAt=CallbackFaultKind=0;
#else
  ModelMismatch=TRUE;
  Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && !Calls,"audit alone never admits cache300 or detaches console");
#endif
  printf("PASS release parent audit: %u parent read boundaries, %d checks; actual production phases, RAM only\n",ReadBudget,Checks);
  return 0;
}
