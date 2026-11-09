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
static unsigned OpenMode,CloseMode,OwnerFault,PreexistingSelf,PassiveReferences,FreeFailurePhase;
static EFI_STATUS FreeFailureStatus;
static BOOLEAN FreeFailureInjected;
static unsigned OwnerQueries;
static UINTN ParentHandleStorage[8];
#define FOREIGN_OWNER ((EFI_HANDLE)(UINTN)61000)
static UINTN SelfReferences(VOID) {
  UINTN count=0;for(UINTN i=0;i<Live.Count;i++)if(Live.Edges[i].Handle==FX_RtxPci &&
    Live.Edges[i].Agent==(VOID *)9999 && GuGuidEqual(&Live.Edges[i].Protocol,&PciGuid))count+=Live.Edges[i].Count;
  return count;
}
static UINTN ForeignReferences(VOID) {
  UINTN count=0;for(UINTN i=0;i<Live.Count;i++)if(Live.Edges[i].Handle==FX_RtxPci &&
    Live.Edges[i].Agent==FOREIGN_OWNER && GuGuidEqual(&Live.Edges[i].Protocol,&PciGuid))count+=Live.Edges[i].Count;
  return count;
}
static EFI_STATUS EFIAPI AuditOpen(EFI_HANDLE h,EFI_GUID *g,VOID **out,EFI_HANDLE agent,EFI_HANDLE controller,UINT32 attrs) {
  Check(ReleaseAudit.HeldQuery!=NULL,"final no-owner query buffer retained until Open");
  int scenario=FullScenario;
  if(OpenMode==1 || OpenMode==2 || OpenMode==5 || OpenMode==14)FullScenario=4;
  EFI_STATUS s=Open(h,g,out,agent,controller,attrs);FullScenario=scenario;
  if(OpenMode==1 || OpenMode==3)return EFI_DEVICE_ERROR;
  if(OpenMode==2 || OpenMode==4)return EFI_WARN_UNKNOWN_GLYPH;
  if(OpenMode==13 || OpenMode==14)return EFI_NOT_STARTED;
  if(OpenMode==5){*out=&RtxPci;return EFI_SUCCESS;}
  if(OpenMode==6)*out=&ParentIo;
  if(OpenMode==7)Live.Edges[Live.Count-1].Count=2;
  if(OpenMode==8)Live.Edges[Live.Count-1].Attributes=EFI_OPEN_PROTOCOL_GET_PROTOCOL;
  if(OpenMode==9)Live.Edges[Live.Count++]=(EDGE){h,agent,NULL,*g,EFI_OPEN_PROTOCOL_GET_PROTOCOL,1};
  if(OpenMode==10)Live.Edges[Live.Count++]=(EDGE){h,FOREIGN_OWNER,h,*g,EFI_OPEN_PROTOCOL_BY_DRIVER,1};
  if(OpenMode==11)Live.Edges[Live.Count++]=(EDGE){h,FOREIGN_OWNER,NULL,*g,EFI_OPEN_PROTOCOL_GET_PROTOCOL,1};
  return s;
}
static EFI_STATUS EFIAPI AuditClose(EFI_HANDLE h,EFI_GUID *g,EFI_HANDLE agent,EFI_HANDLE controller) {
  Check(ReleaseAudit.HeldQuery!=NULL && SelfReferences()==1,"only one precisely attributed self reference may be closed");
  int scenario=FullScenario;
  if(CloseMode==1 || CloseMode==3 || CloseMode==5 || CloseMode==7)FullScenario=13;
  EFI_STATUS s=Close(h,g,agent,controller);FullScenario=scenario;
  if(CloseMode==1 || CloseMode==2)return EFI_DEVICE_ERROR;
  if(CloseMode==3 || CloseMode==4)return EFI_WARN_UNKNOWN_GLYPH;
  if(CloseMode==6 || CloseMode==7)return EFI_NOT_STARTED;
  if(CloseMode==5)return EFI_SUCCESS;
  return s;
}
static EFI_STATUS EFIAPI AuditOwners(EFI_HANDLE h,EFI_GUID *g,EFI_OPEN_PROTOCOL_INFORMATION_ENTRY **p,UINTN *count) {
  OwnerQueries++;
  EFI_STATUS s=Opens(h,g,p,count);
  if(OwnerFault==12 && ReleaseAudit.OwnershipStarted && !ReleaseAudit.OpenInvoked && h==FX_RtxPci && GuGuidEqual(g,&PciGuid))
    return EFI_DEVICE_ERROR;
  if(OwnerFault && ReleaseAudit.OpenInvoked && !ReleaseAudit.CloseInvoked && h==FX_RtxPci && GuGuidEqual(g,&PciGuid)) {
    if(OwnerFault==1)return EFI_DEVICE_ERROR;
    if(OwnerFault==2)return EFI_WARN_UNKNOWN_GLYPH;
    if(OwnerFault==3){*count=65;return s;}
    if(OwnerFault==4){Check(*count==1,"duplicate fault has one real claim");(*p)[1]=(*p)[0];*count=2;return s;}
    if(OwnerFault==11)return EFI_NOT_STARTED;
    if(OwnerFault>=5) {
      Free(*p);
      if(OwnerFault==5)*p=ReleaseAudit.Passive;
      if(OwnerFault==6)*p=NULL;
      if(OwnerFault==7)*p=(VOID *)&ParentHandleStorage[3];
      if(OwnerFault==8)*p=(VOID *)&ParentHandleStorage[2];
      if(OwnerFault==9)*p=(VOID *)((UINT8 *)PreparedGraph+sizeof(UINTN));
      if(OwnerFault==10)*p=(VOID *)((UINT8 *)&ParentHandleStorage[3]+1);
      *count=1;return s;
    }
  }
  return s;
}
static EFI_STATUS EFIAPI AuditFree(VOID *p) {
  UINTN address=(UINTN)p,begin=(UINTN)&ReleaseAudit;
  Check(address<begin || address-begin>=sizeof(ReleaseAudit),"never free borrowed private audit state");
  begin=(UINTN)ParentHandleStorage;
  Check(address<begin || address-begin>=sizeof(ParentHandleStorage),"never free borrowed handle token storage");
  begin=(UINTN)PreparedGraph;
  Check(!PreparedGraph || address<begin || address-begin>=sizeof(*PreparedGraph),"never free borrowed prepared graph");
  BOOLEAN inject=FreeFailurePhase && !FreeFailureInjected && ReleaseAudit.HeldQuery==p &&
    (FreeFailurePhase==1?(ReleaseAudit.OpenInvoked && !ReleaseAudit.CloseInvoked):ReleaseAudit.CloseInvoked);
  EFI_STATUS s=Free(p);
  if(inject){FreeFailureInjected=TRUE;return FreeFailureStatus;}
  return s;
}
#define PARENT_HANDLE ((EFI_HANDLE)&ParentHandleStorage[3])
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
    if(op==EfiPciIoAttributeOperationEnable) {
      Check(mask==EFI_PCI_IO_ATTRIBUTE_MEMORY,"only MEMORY restored");
      Check(ReleaseAudit.HeldQuery!=NULL && SelfReferences()==1,"final exact owner proof retained until Enable");
    }
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
  LastTable->BootServices->OpenProtocol=AuditOpen;LastTable->BootServices->CloseProtocol=AuditClose;
  LastTable->BootServices->OpenProtocolInformation=AuditOwners;LastTable->BootServices->FreePool=AuditFree;
  LastTable->BootServices->RaiseTPL=AuditRaise;LastTable->BootServices->RestoreTPL=AuditRestore;
  for(unsigned i=0;i<PassiveReferences;i++)Live.Edges[Live.Count++]=(EDGE){FX_RtxPci,(EFI_HANDLE)(UINTN)(62000+i),NULL,PciGuid,EFI_OPEN_PROTOCOL_GET_PROTOCOL,1};
  if(PreexistingSelf)Live.Edges[Live.Count++]=(EDGE){FX_RtxPci,(VOID *)9999,NULL,PciGuid,EFI_OPEN_PROTOCOL_GET_PROTOCOL,PreexistingSelf};
}
static void AuditFullSetup(void) {
  RtxPci.Attributes=AuditAttributes;
  LastTable->BootServices->OpenProtocol=AuditOpen;LastTable->BootServices->CloseProtocol=AuditClose;
  if(ModelMismatch)MockAttributes=GU_DS_IO|GU_DS_MEMORY;
}
static EFI_STATUS AuditedRun(unsigned fault,BOOLEAN reenter) {
  /* Each test models a new image. Production has no reset or retry API. */
  ReleaseAudit=(GU_RELEASE_AUDIT_STATE){0};ParentReads=0;FaultRead=fault;Reenter=reenter;Full.Owned=FALSE;
  Injected=FALSE;FirstOwnedRead=PreEnableRead=NvPreflightRead=0;FirstOwnedCapture=0;
  FreeFailureInjected=FALSE;
  OwnerQueries=0;
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
static VOID OwnershipDefaults(VOID) {
  OpenMode=CloseMode=OwnerFault=PreexistingSelf=PassiveReferences=FreeFailurePhase=0;
  CallbackFaultAt=CallbackFaultKind=0;AfterOverride=0;
  VerifyReenter=ParentHandleDrift=FinalRestoreDrift=FALSE;LocationFault=AttributeDevice=0;
  AttributeDelta=SupportedDelta=0;FinalSkipByte=256;FinalReadStatus=EFI_SUCCESS;
}
static VOID OwnershipTests(VOID) {
#ifdef GU_RELEASE_MISMATCH_RESEARCH
  const unsigned routes=2;
#else
  const unsigned routes=1;
#endif
  for(unsigned route=0;route<routes;route++) {
    ModelMismatch=(BOOLEAN)route;
    const unsigned modes[]={1,2,3,4,5,6,7,8,9,10,11,13,14};
    for(UINTN i=0;i<sizeof(modes)/sizeof(modes[0]);i++) {
      OwnershipDefaults();OpenMode=modes[i];
      EFI_STATUS s=AuditedRun(0,FALSE);
      Check(s!=EFI_SUCCESS && !EnableCalls && !Full.Restored,"failed/ambiguous Open never permits MEMORY restore");
      Check(ReleaseAudit.OpenInvoked && ClaimCalls==1,"Open attempted at most once");
      unsigned closeExpected=OpenMode==3 || OpenMode==4 || OpenMode==6 || OpenMode==10 || OpenMode==11 || OpenMode==13;
      Check(CloseCalls==(int)closeExpected,"cleanup requires a fresh unambiguous self reference");
      UINTN expected=OpenMode==7 || OpenMode==9?2:OpenMode==8?1:0;
      Check(SelfReferences()==expected,"ambiguous same-owner references preserved, attributable claim removed");
      if(expected)Check(ReleaseAudit.ClaimMayRemain,"ambiguous claim reported as unresolved");
      if(OpenMode==10 || OpenMode==11)Check(ForeignReferences()==1,"cleanup leaves foreign active/passive references intact");
      if(OpenMode==1 || OpenMode==3)Check(s==EFI_DEVICE_ERROR && ReleaseAudit.OpenStatus==s,"raw Open error preserved after cleanup");
      if(OpenMode==2 || OpenMode==4)Check(s==EFI_WARN_UNKNOWN_GLYPH && ReleaseAudit.OpenStatus==s,"raw Open warning never promoted");
      if(OpenMode==13 || OpenMode==14)Check(s==EFI_NOT_STARTED && ReleaseAudit.OpenStatus==s,"observed NOT_STARTED distinguished from no invocation");
      int calls=ClaimCalls;EFI_PCI_IO_PROTOCOL *io=NULL;
      Check(AuditOwnershipAcquire(&io)==EFI_ACCESS_DENIED && ClaimCalls==calls,"fresh API invocation cannot retry spent Open");
    }
    for(unsigned mode=1;mode<=7;mode++) {
      OwnershipDefaults();CloseMode=mode;
      EFI_STATUS s=AuditedRun(0,FALSE);
      Check(s!=EFI_SUCCESS && EnableCalls==1 && !Full.Restored,"Close failure/retained reference blocks completion after one restore");
      Check(CloseCalls==1 && ReleaseAudit.CloseInvoked && ReleaseAudit.CleanupObserved,"one observed cleanup invocation");
      BOOLEAN retained=mode==1 || mode==3 || mode==5 || mode==7;
      Check(SelfReferences()==(retained?1U:0U) && ReleaseAudit.ClaimMayRemain==retained,"post-Close view records actual residual claim");
      if(mode==1 || mode==2)Check(s==EFI_DEVICE_ERROR && ReleaseAudit.CloseStatus==s,"partial-effect Close error preserved");
      if(mode==3 || mode==4)Check(s==EFI_WARN_UNKNOWN_GLYPH && ReleaseAudit.CloseStatus==s,"partial-effect Close warning preserved");
      if(mode==6 || mode==7)Check(s==EFI_NOT_STARTED && ReleaseAudit.CloseStatus==s,"Close raw NOT_STARTED is observed failure");
      unsigned queries=OwnerQueries;EFI_STATUS cleanup=ReleaseAudit.CleanupStatus;
      Check(AuditOwnershipFinish()==EFI_ALREADY_STARTED && CloseCalls==1 && OwnerQueries==queries && ReleaseAudit.CleanupStatus==cleanup,
        "failed cleanup is never queried/retried and its first result remains intact");
    }
    for(unsigned fault=1;fault<=11;fault++) {
      OwnershipDefaults();OwnerFault=fault;
      Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && !EnableCalls && !CloseCalls,"unreliable owner query cannot attribute cleanup");
      Check(SelfReferences()==1 && ReleaseAudit.ClaimMayRemain,"unknown query leaves claim unresolved without touching it");
      if(fault==11)Check(ReleaseAudit.OwnerObserved && ReleaseAudit.OwnerStatus==EFI_NOT_STARTED,
        "raw owner-query NOT_STARTED is observed failure, not missing evidence");
    }
    const EFI_STATUS failures[]={EFI_DEVICE_ERROR,EFI_WARN_UNKNOWN_GLYPH,EFI_NOT_STARTED};
    for(unsigned phase=1;phase<=2;phase++)for(UINTN i=0;i<3;i++) {
      OwnershipDefaults();FreeFailurePhase=phase;FreeFailureStatus=failures[i];
      Check(AuditedRun(0,FALSE)==failures[i] && FreeFailureInjected,"raw query-buffer Free failure preserved");
      Check(ReleaseAudit.PoolObserved && ReleaseAudit.PoolStatus==failures[i],"later successful Free cannot erase earlier failure");
      Check(!SelfReferences() && CloseCalls==1 && EnableCalls==(phase==1?0:1),"pool failure never grants another write or cleanup retry");
    }
    for(unsigned references=1;references<=2;references++) {
      OwnershipDefaults();PreexistingSelf=references;
      Check(AuditedRun(0,FALSE)!=EFI_SUCCESS && !ClaimCalls && !CloseCalls && !EnableCalls,
        "preexisting same-agent passive reference forbids new Open and cleanup");
      Check(SelfReferences()==references,"preexisting references untouched");
    }
    OwnershipDefaults();OwnerFault=12;
    Check(AuditedRun(0,FALSE)==EFI_DEVICE_ERROR && !ClaimCalls && !ReleaseAudit.OwnerBaselineReady,"failed baseline grants no acquisition authority");
    OwnerFault=0;unsigned queries=OwnerQueries;EFI_PCI_IO_PROTOCOL *retry=NULL;
    Check(AuditOwnershipAcquire(&retry)==EFI_ACCESS_DENIED && OwnerQueries==queries && !ClaimCalls,
      "failed baseline cannot be retried by querying fresh state in the same transaction");
    const unsigned counts[]={0,63,64};
    for(UINTN i=0;i<3;i++) {
      OwnershipDefaults();PassiveReferences=counts[i];
      EFI_STATUS s=AuditedRun(0,FALSE);
      if(counts[i]<64)Check(s==EFI_SUCCESS && ReleaseAudit.PassiveCount==counts[i] && CloseCalls==1,"zero/63 passive boundary with one fresh claim succeeds");
      else Check(s!=EFI_SUCCESS && !ClaimCalls && !CloseCalls && !EnableCalls,"64 passive entries leave no bounded claim slot");
    }
  }
  OwnershipDefaults();
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
  OwnershipTests();FinalTests();
  printf("PASS release parent audit: %u parent read boundaries, %d checks; actual production phases, RAM only\n",ReadBudget,Checks);
  return 0;
}
