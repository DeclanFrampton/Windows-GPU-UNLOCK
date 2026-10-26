/* GPL-2.0-only. Real handoff routing with synthetic EFI callbacks. */
#ifndef GU_AD104_TEXT_TEST
#define GU_AD104_EDID_TEST
#endif
#define main MbrMain
#include "test_mbr_handoff.c"
#undef main
static int RunCalls,StartCalls,Failure;
#ifdef GU_AD104_TEXT_TEST
BOOLEAN GuTextOutputDisabled;
static int OutputCalls;
static EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL QuietOutput;
static EFI_STATUS EFIAPI QuietPrint(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *o,CHAR16 *s){(void)o;(void)s;OutputCalls++;return EFI_SUCCESS;}
#endif
EFI_STATUS GuEdidExperiment(EFI_SYSTEM_TABLE *t,EFI_FILE_PROTOCOL *f) {
  (void)t;(void)f;RunCalls++;return Failure==1?EFI_NOT_READY:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI LogWrite(EFI_FILE_PROTOCOL *f,UINTN *n,VOID *p) {
  (void)f;(void)n;(void)p;return Failure==2?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI LogFlush(EFI_FILE_PROTOCOL *f){(void)f;return Failure==3?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI BootClose(EFI_FILE_PROTOCOL *f) {
  return (Failure==4 && f==&file)||(Failure==5 && f==&root)?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Start(EFI_HANDLE h,UINTN *n,CHAR16 **s) {
  (void)h;(void)n;(void)s;StartCalls++;return EFI_SUCCESS;
}
static void BootSetup(int f) {
  Failure=f;RunCalls=StartCalls=0;
#ifdef GU_AD104_TEXT_TEST
  GuTextOutputDisabled=TRUE;OutputCalls=0;QuietOutput.OutputString=QuietPrint;
#endif
  memset(&bs,0,sizeof(bs));memset(&table,0,sizeof(table));memset(&file,0,sizeof(file));memset(&root,0,sizeof(root));
  table.BootServices=&bs;Table=&table;Log=&file;Root=&root;WindowsImage=(VOID *)100;
#ifdef GU_AD104_TEXT_TEST
  table.ConOut=&QuietOutput;
#endif
  bs.StartImage=Start;file.Write=LogWrite;file.Flush=LogFlush;file.Close=root.Close=BootClose;
}
int main(void) {
  for(int f=0;f<=5;f++) {
    BootSetup(f);EFI_STATUS s=EdidThenWindows(EFI_NOT_READY,EFI_SUCCESS);
    CHECK((s==EFI_SUCCESS)==(f==0));CHECK(RunCalls==1 && StartCalls==(f==0));
#ifdef GU_AD104_TEXT_TEST
    Say(L"must remain quiet");CHECK(!OutputCalls);
#endif
  }
  BootSetup(0);CHECK(EdidThenWindows(EFI_NOT_READY,EFI_DEVICE_ERROR)!=EFI_SUCCESS && !RunCalls && !StartCalls);
  BootSetup(0);CHECK(EdidThenWindows(EFI_DEVICE_ERROR,EFI_SUCCESS)!=EFI_SUCCESS && !RunCalls && !StartCalls);
  BootSetup(0);WindowsImage=NULL;CHECK(EdidThenWindows(EFI_NOT_READY,EFI_SUCCESS)!=EFI_SUCCESS && !RunCalls && !StartCalls);
  printf("PASS EDID Windows handoff: %d checks, RAM-only mocks\n",checks);return 0;
}
