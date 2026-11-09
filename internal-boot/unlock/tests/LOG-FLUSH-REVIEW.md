# PR #335 flush-status companion

Based on PR #335 head `db5c9209d6f88d6de4a4cbff8b8e3612022e243a`.

The new `GuLogFlush` tested only the signed error bit. In headless mode this
bypassed `app_io.c`'s existing policy that every non-success EFI status is a
failure. A warning could therefore leave `GuLogReady()` true at the final
ARMED logging gate. The one-line correction uses the existing `EFI_ERROR`
policy. Normal-mode warning semantics are unchanged.

The host harness includes the production `app_io.c`, substitutes RAM-only file
and console callbacks, and calls only logging functions. Unused functions are
discarded by the host linker. It never opens a filesystem protocol, starts a GPU
transaction, accesses firmware or creates an EFI image. Freestanding builds of
the harness are explicitly rejected.

## Reproduce on Linux x64

Use an already installed GCC or Clang, Python 3 and the repository's headers:

```sh
python internal-boot/unlock/tests/test_log_flush.py --cc gcc
python internal-boot/unlock/tests/test_log_flush.py --cc gcc --sanitize
```

The unmodified PR head fails the headless warning case. The fix passes 40
headless checks and 36 normal-mode checks covering success, four warning
classes, three errors, sticky faults, absent report and headless console
suppression. The runner also checks that the freestanding build is refused for
the intended reason.

Verified with GCC 14.2.0 and Python 3.12.14. AddressSanitizer and UBSan passed for
both configurations. LeakSanitizer could not run under this environment's
ptrace tracing, so those runs used `ASAN_OPTIONS=detect_leaks=0`; leak checking
is not claimed. Native Windows/compiler/EFI and hardware behavior are untested.

This is a review patch, not a release or hardware approval. Source manifests
were not refreshed. PR #335's USB/system-partition staging issue and other
utility changes require separate review; no admission or recovery guarantees
are broadened here.
