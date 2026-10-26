/* GPL-2.0-only. Real handoff routing with synthetic EFI callbacks. */
#define GU_AD104_EDID_TEST
#define main MbrMain
#include "test_mbr_handoff.c"
#undef main
static int RunCalls,StartCalls,Failure;
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
  memset(&bs,0,sizeof(bs));memset(&table,0,sizeof(table));memset(&file,0,sizeof(file));memset(&root,0,sizeof(root));
  table.BootServices=&bs;Table=&table;Log=&file;Root=&root;WindowsImage=(VOID *)100;
  bs.StartImage=Start;file.Write=LogWrite;file.Flush=LogFlush;file.Close=root.Close=BootClose;
}
int main(void) {
  for(int f=0;f<=5;f++) {
    BootSetup(f);EFI_STATUS s=EdidThenWindows(EFI_NOT_READY,EFI_SUCCESS);
    CHECK((s==EFI_SUCCESS)==(f==0));CHECK(RunCalls==1 && StartCalls==(f==0));
  }
  BootSetup(0);CHECK(EdidThenWindows(EFI_NOT_READY,EFI_DEVICE_ERROR)!=EFI_SUCCESS && !RunCalls && !StartCalls);
  BootSetup(0);CHECK(EdidThenWindows(EFI_DEVICE_ERROR,EFI_SUCCESS)!=EFI_SUCCESS && !RunCalls && !StartCalls);
  BootSetup(0);WindowsImage=NULL;CHECK(EdidThenWindows(EFI_NOT_READY,EFI_SUCCESS)!=EFI_SUCCESS && !RunCalls && !StartCalls);
  printf("PASS EDID Windows handoff: %d checks, RAM-only mocks\n",checks);return 0;
}
