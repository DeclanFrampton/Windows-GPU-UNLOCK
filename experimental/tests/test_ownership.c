/* SPDX-License-Identifier: GPL-2.0-only */
/* Hosted only: compile the real predicate, discard the uncalled engine via
 * --gc-sections. No EFI service, vendor transaction, MMIO or FLR is linked. */
#if !defined(__STDC_HOSTED__) || __STDC_HOSTED__ != 1
#error "Ownership predicate harness requires hosted compilation"
#endif
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef OWNERSHIP_SOURCE
#define OWNERSHIP_SOURCE "../src/unlock_engine.c"
#endif
#undef NULL
#include OWNERSHIP_SOURCE

static EFI_BOOT_SERVICES boot;
EFI_BOOT_SERVICES *gBS = &boot;
static EFI_PCI_IO_PROTOCOL pci;
static DETECTED_GPU gpu;
static EFI_OPEN_PROTOCOL_INFORMATION_ENTRY owners[4096];
static EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *result;
static EFI_STATUS query_status, read_status;
static UINTN result_count;
static UINT16 command;
static unsigned queries, reads, frees, passed;

VOID LogWrite(CONST CHAR8 *format, ...) { (void)format; }

static EFI_STATUS EFIAPI mock_read(EFI_PCI_IO_PROTOCOL *self,
    EFI_PCI_IO_PROTOCOL_WIDTH width, UINT32 offset, UINTN count, VOID *buffer) {
  assert(self == &pci && width == EfiPciIoWidthUint16);
  assert(offset == 4 && count == 1);
  ++reads;
  if (read_status == EFI_SUCCESS) *(UINT16 *)buffer = command;
  return read_status;
}
static EFI_STATUS EFIAPI mock_query(EFI_HANDLE handle, EFI_GUID *protocol,
    EFI_OPEN_PROTOCOL_INFORMATION_ENTRY **entries, UINTN *count) {
  EFI_GUID expected = EFI_PCI_IO_PROTOCOL_GUID;
  assert(handle == gpu.handle && memcmp(protocol, &expected, sizeof expected) == 0);
  assert(*entries == NULL && *count == 0);
  ++queries;
  *entries = result;
  *count = result_count;
  return query_status;
}
static EFI_STATUS EFIAPI mock_free(VOID *buffer) {
  assert(buffer == owners && frees == 0);
  ++frees;
  return EFI_SUCCESS;
}
static void reset(void) {
  memset(&boot, 0, sizeof boot);
  memset(&pci, 0, sizeof pci);
  memset(&gpu, 0, sizeof gpu);
  memset(owners, 0, sizeof owners);
  boot.OpenProtocolInformation = mock_query;
  boot.FreePool = mock_free;
  pci.Pci.Read = mock_read;
  gpu.pci_io = &pci;
  gpu.handle = &gpu;
  g_current_unlock_gpu = &gpu;
  result = owners;
  result_count = 0;
  query_status = read_status = EFI_SUCCESS;
  command = 2;
  queries = reads = frees = 0;
}
static void check(const char *name, BOOLEAN expected, unsigned free_count,
                  unsigned query_count, unsigned read_count) {
  BOOLEAN actual = CheckGpuDisplayAndOwnershipOk();
  if (actual != expected || frees != free_count || queries != query_count || reads != read_count) {
    fprintf(stderr, "FAIL %s: result=%u free=%u query=%u read=%u\n",
            name, actual, frees, queries, reads);
    exit(1);
  }
  ++passed;
}
int main(int argc, char **argv) {
  /* This intentionally checks the old unsafe behavior to reproduce the bug. */
  if (argc == 2 && strcmp(argv[1], "--baseline") == 0) {
    reset(); query_status = EFI_OUT_OF_RESOURCES; result = NULL;
    check("baseline resource error accepted", TRUE, 0, 1, 1);
    reset(); query_status = EFI_DEVICE_ERROR; result = NULL;
    check("baseline device error accepted", TRUE, 0, 1, 1);
    reset(); result = NULL; result_count = 1;
    check("baseline absent owner list accepted", TRUE, 0, 1, 1);
    printf("Baseline reproduced: %u unsafe acceptances\n", passed);
    return 0;
  }
  reset(); check("allocated empty list", TRUE, 1, 1, 1);
  reset(); result_count = 3;
  owners[0].Attributes = EFI_OPEN_PROTOCOL_GET_PROTOCOL;
  owners[1].Attributes = EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL;
  owners[2].Attributes = EFI_OPEN_PROTOCOL_TEST_PROTOCOL;
  check("existing allowed attributes", TRUE, 1, 1, 1);
  EFI_STATUS failures[] = { EFI_OUT_OF_RESOURCES, EFI_DEVICE_ERROR,
    EFI_NOT_FOUND, EFI_INVALID_PARAMETER, EFI_WARN_UNKNOWN_GLYPH };
  for (size_t i = 0; i < sizeof failures / sizeof failures[0]; ++i) {
    reset(); query_status = failures[i]; result = NULL;
    check("non-success absent output", FALSE, 0, 1, 1);
    reset(); query_status = failures[i];
    result = (EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *)(UINTN)1;
    result_count = MAX_UINTN;
    check("non-success poison output untouched", FALSE, 0, 1, 1);
  }
  reset(); result = NULL; check("null empty result", FALSE, 0, 1, 1);
  reset(); result = NULL; result_count = 1;
  check("null nonempty result", FALSE, 0, 1, 1);
  reset(); result_count = 4097; check("oversized list", FALSE, 1, 1, 1);
  reset(); result_count = MAX_UINTN; check("impossible count", FALSE, 1, 1, 1);
  reset(); result_count = 4096; check("scan limit allowed", TRUE, 1, 1, 1);
  reset(); result_count = 4096; owners[4095].Attributes = EFI_OPEN_PROTOCOL_BY_DRIVER;
  check("last owner blocks", FALSE, 1, 1, 1);
  UINT32 blocked[] = { EFI_OPEN_PROTOCOL_BY_DRIVER, EFI_OPEN_PROTOCOL_EXCLUSIVE,
    EFI_OPEN_PROTOCOL_BY_DRIVER | EFI_OPEN_PROTOCOL_EXCLUSIVE };
  for (size_t i = 0; i < sizeof blocked / sizeof blocked[0]; ++i) {
    reset(); result_count = 3; owners[1].Attributes = blocked[i];
    check("driver or exclusive owner", FALSE, 1, 1, 1);
  }
  reset(); read_status = EFI_DEVICE_ERROR; check("read failure", FALSE, 0, 0, 1);
  reset(); command = 0; check("decode off", FALSE, 0, 0, 1);
  reset(); command = 6; check("DMA on", FALSE, 0, 0, 1);
  for (int flag = 0; flag < 3; ++flag) {
    reset();
    if (flag == 0) gpu.is_display_adapter = TRUE;
    if (flag == 1) gpu.has_active_gop = TRUE;
    if (flag == 2) gpu.is_console_display = TRUE;
    check("display unreleased", FALSE, 0, 0, 1);
    gpu.display_released = TRUE; reads = 0;
    check("display released empty owners", TRUE, 1, 1, 1);
  }
  reset(); g_current_unlock_gpu = NULL; check("missing GPU", FALSE, 0, 0, 0);
  reset(); gpu.pci_io = NULL; check("missing PCI", FALSE, 0, 0, 0);
  reset(); gpu.handle = NULL; check("missing handle", FALSE, 0, 0, 0);
  printf("PASS: %u production-predicate RAM-only cases\n", passed);
  return 0;
}
