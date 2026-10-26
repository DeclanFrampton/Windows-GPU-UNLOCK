/* GPL-2.0-only. Firmware resource metadata callbacks in RAM only. */
#define GU_AD104_TEST_REUSE
#include "test_probe_ad104.c"
static int Calls,Fault;
static EFI_STATUS EFIAPI ResourceBar(EFI_PCI_IO_PROTOCOL *io,UINT8 index,UINT64 *supports,VOID **out) {
  Calls++;if(supports)*supports=0;
  if(Fault==1){*out=NULL;return EFI_NOT_FOUND;}
  EFI_STATUS s=Bar(io,index,supports,out);
  if(s==EFI_SUCCESS && Fault==2)((EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *)*out)->Desc=0;
  return s;
}
static EFI_STATUS EFIAPI ResourceRead(EFI_PCI_IO_PROTOCOL *io,EFI_PCI_IO_PROTOCOL_WIDTH w,UINT32 at,UINTN n,VOID *out) {
  EFI_STATUS s=AdRead(io,w,at,n,out);
  if(s==EFI_SUCCESS && n==64 && Fault==3 && Calls)((UINT32 *)out)[11]^=1;
  return s;
}
static void RunResource(int mode,int fault) {
  GenericSetup(mode);AdMode=mode;Calls=0;Fault=fault;
  Pci.Pci.Read=ResourceRead;Pci.GetLocation=AdLocation;Pci.Mem.Read=AdMem;Pci.GetBarAttributes=ResourceBar;
  Check(GuCaptureGraphOnVolume(&Table,&LogFile,&RootFile)==EFI_NOT_READY,"resource observation remains incomplete GPU capture");
  Check(!S.RegReads && !S.PromReads,"resource observation never reads GPU MMIO");
}
int main(void) {
  RunResource(G_BME,0);
  Check(Calls==1 && Logged("descriptor-valid=1 envelope-shape=1"),"valid descriptor observed with BME enabled");
  Check(Logged("bus-master-enabled=1") && Logged("unlock-eligibility=0"),"BME never changed or used for eligibility");
  for(int f=1;f<=3;f++) {
    RunResource(G_BME,f);
    Check(!Logged("ad104-bar0-resource"),"error, malformed descriptor or identity drift refuses resource record");
  }
  RunResource(G_BAD_RESOURCE,0);
  Check(Logged("descriptor-valid=1 envelope-shape=0"),"resource shape mismatch is separate from descriptor validity");
  RunResource(G_BAD_CHECKSUM,0);
  Check(Logged("descriptor-valid=0 envelope-shape=0"),"bad checksum rejected");
  const int modes[]={A_DEVICE,A_SUBSYSTEM,A_REVISION,G_MULTI};
  for(UINTN i=0;i<4;i++) {
    RunResource(modes[i],0);
    Check(!Calls,"identity/inventory mismatch never queries resources");
  }
  printf("PASS AD104 resources: %d checks, RAM-only\n",Checks);
  return 0;
}
