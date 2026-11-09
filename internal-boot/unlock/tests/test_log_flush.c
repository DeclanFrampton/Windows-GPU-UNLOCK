/* Host-only logging policy regression. No firmware, filesystem or hardware calls. */
#include "../app_io.c"
#include <stdio.h>

#if __STDC_HOSTED__ != 1
#error This is a hosted RAM-only test, never a firmware build.
#endif
#ifdef GU_HEADLESS_RESEARCH
#define EXPECT_READY(Status) ((Status) == EFI_SUCCESS)
#else
#define EXPECT_READY(Status) (((INTN)(Status)) >= 0)
#endif

static EFI_STATUS FlushStatus;
static unsigned WriteCalls, FlushCalls, ConsoleCalls, Checks;

static EFI_STATUS EFIAPI FakeConsole(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *Output, CHAR16 *Text) {
  (void)Output; (void)Text;
  ++ConsoleCalls;
  return EFI_SUCCESS;
}

static EFI_STATUS EFIAPI FakeWrite(EFI_FILE_PROTOCOL *File, UINTN *Size, VOID *Buffer) {
  (void)File; (void)Size; (void)Buffer;
  ++WriteCalls;
  return EFI_SUCCESS;
}

static EFI_STATUS EFIAPI FakeFlush(EFI_FILE_PROTOCOL *File) {
  (void)File;
  ++FlushCalls;
  return FlushStatus;
}

#define CHECK(Test) do { ++Checks; if (!(Test)) { \
  fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #Test); return 1; } } while (0)

int main(void) {
  EFI_FILE_PROTOCOL file = {0};
  file.Write = FakeWrite;
  file.Flush = FakeFlush;
  EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL output = {0};
  output.OutputString = FakeConsole;
  EFI_SYSTEM_TABLE table = {0};
  table.ConOut = &output;
  Table = &table;
  const EFI_STATUS statuses[] = {
    EFI_SUCCESS, EFI_WARN_UNKNOWN_GLYPH, EFI_WARN_DELETE_FAILURE,
    EFI_WARN_WRITE_FAILURE, EFI_WARN_BUFFER_TOO_SMALL,
    EFI_DEVICE_ERROR, EFI_VOLUME_FULL, EFI_ACCESS_DENIED
  };
  for (UINTN i = 0; i < sizeof(statuses) / sizeof(statuses[0]); ++i) {
    Report = &file; LogFault = FALSE;
    WriteCalls = FlushCalls = ConsoleCalls = 0; FlushStatus = statuses[i];
    /* Same order as the final ARMED logging gate; no transaction is called. */
    GuLogText("ARMED: synthetic host test only.\n");
    GuLogFlush();
    CHECK(WriteCalls == 1);
    CHECK(FlushCalls == 1);
    CHECK(GuLogReady() == EXPECT_READY(FlushStatus));
#ifdef GU_HEADLESS_RESEARCH
    CHECK(ConsoleCalls == 0);
#else
    CHECK(ConsoleCalls == 1);
#endif
    if (!EXPECT_READY(FlushStatus)) {
      FlushStatus = EFI_SUCCESS;
      GuLogFlush();
      CHECK(!GuLogReady()); /* A later success cannot clear a prior log fault. */
    }
  }
  Report = NULL; LogFault = FALSE;
  GuLogFlush();
  CHECK(!GuLogReady());
  printf("PASS: %u flush policy checks; RAM-only fake callbacks.\n", Checks);
  return 0;
}
