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
static BOOLEAN VerifyReenter,ParentHandleDrift;
static unsigned VerifyReentries,LocationFault,AttributeDevice;
static UINT64 AttributeDelta,SupportedDelta;
static unsigned TplDepth,TplRaises,TplRestores;
static UINTN FinalSkipByte=256;
static EFI_STATUS FinalReadStatus;
static UINT32 ParentInitialStatus;
static BOOLEAN FinalRestoreDrift;
#define PARENT_HANDLE ((EFI_HANDLE)(UINTN)50001)
static EFI_STATUS EFIAPI AuditHandle(EFI_HANDLE h,EFI_GUID *g,VOID **out) {
  if(h==PARENT_HANDLE || h==(EFI_HANDLE)(UINTN)50002) {
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
    UINTN body=p[18]==0x7f?18:24;*h=body==18?(ParentHandleDrift?(EFI_HANDLE)(UINTN)50002:PARENT_HANDLE):FX_RtxPci;
    *rest=(VOID *)(p+body);return EFI_SUCCESS;
  }
  return FindPci(g,rest,h);
}
static EFI_STATUS EFIAPI AuditLocation(EFI_PCI_IO_PROTOCOL *io,UINTN *s,UINTN *b,UINTN *d,UINTN *f) {
  if(io==&ParentIo){*s=GU_TARGET_SEGMENT;*b=0;*d=ParentPath[17];*f=ParentPath[16];
    if(LocationFault==1)(*s)^=1;if(LocationFault==2)(*b)^=1;
    if(LocationFault==3)(*d)^=1;if(LocationFault==4)(*f)^=1;return EFI_SUCCESS;}
  return Location(io,s,b,d,f);
}
static EFI_STATUS EFIAPI AuditRead(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_WIDTH w,UINT32 offset,UINTN n,VOID *out) {
  if(VerifyReenter && ReleaseAudit.Verifying) {
    GU_VERIFY_DIAGNOSTIC diag=*GuLastVerifyDiagnostic();UINTN next=ReleaseAudit.Next;
    unsigned reads=ParentReads,raises=TplRaises,restores=TplRestores;
    Check(GuVerifyReleased(LastTable,FALSE)==EFI_ALREADY_STARTED,"recursive verifier refused before callbacks/reset");
    const GU_VERIFY_DIAGNOSTIC *now=GuLastVerifyDiagnostic();
    Check(next==ReleaseAudit.Next && reads==ParentReads && raises==TplRaises && restores==TplRestores,
      "recursive verify preserves capture budget and TPL");
    Check(diag.Stage==now->Stage && diag.Status==now->Status && diag.ConfigDiff==now->ConfigDiff &&
      diag.Offset==now->Offset && diag.Expected==now->Expected && diag.Observed==now->Observed,"recursive verifier preserves diagnosis");
    VerifyReentries++;
  }
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
  for(UINTN i=0;i<sizeof(ParentConfig);i++)if(i!=FinalSkipByte)((UINT8 *)out)[i]=((UINT8 *)ParentConfig)[i];
  if(ParentReads==FaultRead)((UINT32 *)out)[63]^=1;
  return FinalReadStatus;
}
static EFI_STATUS EFIAPI AuditAttributes(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_ATTRIBUTE_OPERATION op,UINT64 mask,UINT64 *out) {
  if(io!=&ParentIo) {
    if(op==EfiPciIoAttributeOperationEnable)Check(mask==EFI_PCI_IO_ATTRIBUTE_MEMORY,"only MEMORY restored");
    EFI_STATUS s=Attributes(io,op,mask,out);
    if(s==EFI_SUCCESS && op==EfiPciIoAttributeOperationGet && Phase==4 && !EnableCalls && AfterOverride)*out=AfterOverride;
    if(s==EFI_SUCCESS && AttributeDevice==2 && out) {
      if(op==EfiPciIoAttributeOperationGet)*out^=AttributeDelta;
      if(op==EfiPciIoAttributeOperationSupported)*out^=SupportedDelta;
    }
    return s;
  }
  Check(!mask && out && (op==EfiPciIoAttributeOperationGet || op==EfiPciIoAttributeOperationSupported),"parent is read-only");
  *out=op==EfiPciIoAttributeOperationGet?GU_DS_MEMORY:GU_DS_IO|GU_DS_MEMORY|GU_DS_MASTER;
  if(AttributeDevice==1)*out^=op==EfiPciIoAttributeOperationGet?AttributeDelta:SupportedDelta;
  return EFI_SUCCESS;
}
static EFI_TPL EFIAPI AuditRaise(EFI_TPL level) {
  Check(level==TPL_NOTIFY,"only known TPL raise");TplRaises++;return TplDepth++?TPL_NOTIFY:TPL_APPLICATION;
}
static VOID EFIAPI AuditRestore(EFI_TPL previous) {
  Check(TplDepth>0,"TPL restore has a matching raise");TplDepth--;TplRestores++;
  Check(previous==(TplDepth?TPL_NOTIFY:TPL_APPLICATION),"TPL restored to previous level");
  if(FinalRestoreDrift && ReleaseAudit.Verifying && !strcmp(GuLastVerifyDiagnostic()->Stage,"verify-complete"))
    LastTable->BootServices->CloseProtocol=NULL;
}
static void AuditConsoleSetup(void) {
  Check(sizeof(TestRtxPath)==36,"two PCI nodes in this synthetic fixture");
  memcpy(ControllerPath,TestRtxPath,24);memcpy(ControllerPath+24,"\x7f\xff\x04\x00",4);
  memcpy(ParentPath,TestRtxPath,18);memcpy(ParentPath+18,"\x7f\xff\x04\x00",4);
  memset(ParentConfig,0,sizeof(ParentConfig));ParentConfig[0]=0x14831022;ParentConfig[1]=2;
  ParentConfig[2]=0x06040000;ParentConfig[3]=0x00010000;ParentConfig[6]=(GU_TARGET_BUS<<16)|(GU_TARGET_BUS<<8);
  ParentConfig[32]=ParentInitialStatus;
  ParentIo=(EFI_PCI_IO_PROTOCOL){0};ParentIo.GetLocation=AuditLocation;ParentIo.Pci.Read=AuditRead;ParentIo.Attributes=AuditAttributes;
  memcpy(MockConfig,InitialFullConfig,sizeof(MockConfig));MockAttributes=ModelMismatch?GU_DS_IO|GU_DS_MEMORY:GU_DS_MEMORY;
  RtxPci.GetLocation=AuditLocation;RtxPci.Pci.Read=AuditRead;RtxPci.Attributes=AuditAttributes;
  LastTable->BootServices->HandleProtocol=AuditHandle;LastTable->BootServices->LocateDevicePath=AuditFind;
  LastTable->BootServices->OpenProtocol=Open;LastTable->BootServices->CloseProtocol=Close;
  LastTable->BootServices->RaiseTPL=AuditRaise;LastTable->BootServices->RestoreTPL=AuditRestore;
}
static void AuditFullSetup(void) {
  RtxPci.Attributes=AuditAttributes;
  if(ModelMismatch)MockAttributes=GU_DS_IO|GU_DS_MEMORY;
}
static EFI_STATUS AuditedRun(unsigned fault,BOOLEAN reenter) {
  /* Each test models a new image. Production has no reset or retry API. */
  ReleaseAudit=(GU_RELEASE_AUDIT_STATE){0};ParentReads=0;FaultRead=fault;Reenter=reenter;Full.Owned=FALSE;
  Injected=FALSE;FirstOwnedRead=PreEnableRead=NvPreflightRead=0;FirstOwnedCapture=0;
  TplDepth=TplRaises=TplRestores=0;
  EFI_STATUS s=RunFull(0);Check(!TplDepth && TplRaises==TplRestores,"whole release restores TPL on every result");return s;
}
static VOID FinalReady(BOOLEAN mismatch) {
  ModelMismatch=mismatch;CallbackFaultAt=CallbackFaultKind=0;AfterOverride=0;
  VerifyReenter=ParentHandleDrift=FinalRestoreDrift=FALSE;LocationFault=AttributeDevice=0;AttributeDelta=SupportedDelta=0;
  FinalSkipByte=256;FinalReadStatus=EFI_SUCCESS;
  Check(AuditedRun(0,FALSE)==EFI_SUCCESS,"fresh complete release for final verification");
}
static VOID FinalRefused(BOOLEAN cold) {
  int writes=EnableCalls,stops=Calls;
  Check(GuVerifyReleased(LastTable,cold)!=EFI_SUCCESS,"final drift/invalid observation refused");
  Check(!ReleaseAudit.Verifying && !TplDepth && TplRaises==TplRestores,"failed final verification releases guard and TPL");
  Check(writes==EnableCalls && stops==Calls,"final verifier cannot repeat restore or stop drivers");
}
static VOID FinalTests(VOID) {
  UINT32 originalLayout=InitialFullConfig[30],originalStatus=InitialFullConfig[32];
  InitialFullConfig[30]=0x0012b410;InitialFullConfig[32]=0x00092930;
#ifdef GU_RELEASE_MISMATCH_RESEARCH
  const unsigned routes=2;
#else
  const unsigned routes=1;
#endif
  for(unsigned route=0;route<routes;route++) {
    const UINT32 masks[]={0x10000,0x80000,0x90000};
    for(UINTN i=0;i<3;i++) {
      FinalReady((BOOLEAN)route);MockConfig[32]&=~masks[i];
      Check(GuVerifyReleased(LastTable,FALSE)==EFI_SUCCESS,"only existing reviewed GPU status clears accepted after child");
      Check(Full.Config[32]==InitialFullConfig[32] && ReleaseAudit.Captures[0].Snapshot.Gpu.Config[32]==InitialFullConfig[32],
        "status acceptance never rewrites the observed baseline");
      FinalReady((BOOLEAN)route);MockConfig[32]&=~masks[i];FinalRefused(TRUE);
    }
    FinalReady((BOOLEAN)route);MockConfig[32]|=0x20000;FinalRefused(FALSE);
    FinalReady((BOOLEAN)route);MockConfig[32]^=2;FinalRefused(FALSE);
    InitialFullConfig[30]^=0x100;
    FinalReady((BOOLEAN)route);MockConfig[32]&=~0x90000;FinalRefused(FALSE);
    InitialFullConfig[30]^=0x100;
    InitialFullConfig[32]&=~0x90000;
    FinalReady((BOOLEAN)route);MockConfig[32]|=0x10000;FinalRefused(FALSE);
    InitialFullConfig[32]=0x00092930;
    for(UINTN word=0;word<64;word++) {
      FinalReady((BOOLEAN)route);ParentConfig[word]^=1;FinalRefused(FALSE);
      FinalReady((BOOLEAN)route);MockConfig[word]^=1;FinalRefused(FALSE);
    }
    for(UINTN byte=0;byte<256;byte++) {
      FinalReady((BOOLEAN)route);FinalSkipByte=byte;FinalRefused(FALSE);
    }
    for(unsigned location=1;location<=4;location++) {
      FinalReady((BOOLEAN)route);LocationFault=location;FinalRefused(FALSE);
    }
    FinalReady((BOOLEAN)route);ParentHandleDrift=TRUE;FinalRefused(FALSE);
    for(unsigned device=1;device<=2;device++) {
      FinalReady((BOOLEAN)route);AttributeDevice=device;SupportedDelta=0x80000000;FinalRefused(FALSE);
      FinalReady((BOOLEAN)route);AttributeDevice=device;AttributeDelta=device==1?0x80000000:GU_DS_IO;FinalRefused(FALSE);
    }
    const EFI_STATUS bad[]={EFI_WARN_UNKNOWN_GLYPH,EFI_DEVICE_ERROR};
    for(UINTN i=0;i<2;i++){FinalReady((BOOLEAN)route);FinalReadStatus=bad[i];FinalRefused(FALSE);}
    ParentInitialStatus=0x90000;
    FinalReady((BOOLEAN)route);ParentConfig[32]&=~0x90000;FinalRefused(FALSE);ParentInitialStatus=0;
    FinalReady((BOOLEAN)route);CallbackFaultAt=ParentReads+1;CallbackFaultKind=6;
    FinalRefused(FALSE);Check(Injected,"foreign graph introduced in typed final callback reaches legacy final guard");
    FinalReady((BOOLEAN)route);FinalRestoreDrift=TRUE;FinalRefused(FALSE);
    Check(!strcmp(GuLastVerifyDiagnostic()->Stage,"verify-final-bindings") && GuLastVerifyDiagnostic()->Status==EFI_NOT_READY,
      "post-RestoreTPL method drift reports the actual failure, not verify-complete");
    FinalReady((BOOLEAN)route);VerifyReenter=TRUE;
    unsigned nested=VerifyReentries;
    Check(GuVerifyReleased(LastTable,FALSE)==EFI_SUCCESS && VerifyReentries>nested,"legitimate outer verify survives recursive attempts");
    VerifyReenter=FALSE;
    while(ReleaseAudit.Next<GU_RELEASE_AUDIT_CAPTURES)
      Check(GuVerifyReleased(LastTable,FALSE)==EFI_SUCCESS,"legitimate repeated handoff checks consume bounded fresh observations");
    unsigned reads=ParentReads;UINTN next=ReleaseAudit.Next;
    FinalRefused(FALSE);
    Check(ReleaseAudit.Failed && reads==ParentReads && next==ReleaseAudit.Next,"capture exhaustion refuses without callbacks or reuse");
    FinalReady((BOOLEAN)route);Check(GuVerifyReleased(LastTable,FALSE)==EFI_SUCCESS,"new image works after prior failure/exhaustion");
  }
  InitialFullConfig[30]=originalLayout;InitialFullConfig[32]=originalStatus;
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
  FinalTests();
  printf("PASS release parent audit: %u parent read boundaries, %d checks; actual production phases, RAM only\n",ReadBudget,Checks);
  return 0;
}
