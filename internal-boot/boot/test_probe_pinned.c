/* RAM-only regression for additive exact-target diagnostic pins. */
#define GU_PROBE_PARENT_FIXTURE
#include "test_probe_generic.c"
#undef main
static EFI_STATUS Pinned(UINT32 id,UINT32 subsystem,UINTN segment) {
  GenericSetup(G_OK);TestId=id;TestSubsystem=subsystem;TestSegment=segment;
  return GuCaptureGraphOnVolume(&Table,&LogFile,&RootFile);
}
int main(void) {
  Check(Pinned(0x250410deU,0x263019daU,0)==EFI_SUCCESS,"exact Zotac target captured");
  Check(S.RegReads==16 && S.PromReads==PROM_DWORDS && !AttributeOthers,"exact target retains bounded reads and no attribute writes");
  Check(Pinned(0x250410deU,0x263119daU,0)==EFI_NOT_READY,"different subsystem refused");
  Check(!S.RegReads && !S.PromReads,"subsystem mismatch blocks all MMIO");
  Check(Pinned(0x220410deU,0x263019daU,0)==EFI_NOT_READY,"another reviewed device is still refused by exact pin");
  Check(!S.RegReads && !S.PromReads,"device mismatch blocks all MMIO");
  Check(Pinned(0x250410deU,0x263019daU,1)==EFI_NOT_READY,"nonzero segment refused");
  Check(!S.RegReads && !S.PromReads,"segment mismatch blocks all MMIO");
  GenericSetup(G_CHANGED);TestId=0x250410deU;TestSubsystem=0x263019daU;
  Check(GuCaptureGraphOnVolume(&Table,&LogFile,&RootFile)==EFI_NOT_READY,"subsystem drift after initial pin refused");
  Check(!S.RegReads && !S.PromReads,"drifted pinned subsystem blocks MMIO");
  GenericSetup(G_ATTR_BME);TestId=0x250410deU;TestSubsystem=0x263019daU;
  Check(GuCaptureGraphOnVolume(&Table,&LogFile,&RootFile)==EFI_NOT_READY,"attribute callback BME drift refused");
  Check(!S.RegReads && !S.PromReads,"BME drift blocks MMIO on the exact target");
  printf("PASS exact probe pin checks: %d; RAM mocks only\n",Checks);
  return 0;
}
