# PR #335 sticky logging fault regression

Based on contributor head `6f1b1b6c89520bc7b6cadce76bd717c9d502e938`.

The production change adds only two guards: `GuLogText` no longer writes to
`Report` after `LogFault` is latched, and `GuLogFlush` no longer retries the
faulted file protocol. Normal-mode console diagnostics remain available.
The contributor's policy rejecting **every non-success flush status in both
modes** is unchanged. USB staging and PowerShell are untouched.

The test includes the actual `app_io.c` and calls only its logging functions
with RAM-only file and console callbacks. Unused production functions are
discarded by the host linker. It performs no filesystem protocol, firmware,
GPU or transaction calls and creates no EFI image. Freestanding compilation
of the harness is explicitly rejected.

## Reproduce on Linux x64

Use an already installed GCC or Clang and the repository headers:

```sh
python internal-boot/unlock/tests/test_log_flush.py --cc gcc
ASAN_OPTIONS=detect_leaks=0 python internal-boot/unlock/tests/test_log_flush.py --cc gcc --sanitize
```

On the unchanged contributor source, the harness fails the forbidden flush
retry assertion in both modes. With the two guards it passes 71 headless and
78 normal-mode assertions. Coverage includes successful flush, four positive
warning classes, three errors, short writes, write errors, callback suppression
after sticky faults, missing report, normal-mode console failure and headless
console suppression. Warnings remain readiness failures in **both** modes.

Verified using GCC 14.2.0 and Python 3.12.14. AddressSanitizer and UBSan passed
in both modes with leak detection disabled; leak checking is not claimed.
An independent readiness-only harness also passed 32 checks per mode against
the fixed source, preserving the contributor's warning/error readiness results.

No full application test suite, native Windows, PowerShell, utility, staging,
assets, EFI build/execution, firmware, GPU or system-settings operation was run.
The Python preservation suite was not rerun for this isolated two-guard change;
its current `test_powershell_mock_regressions` starts PowerShell despite the
module's historical docstring and is outside these host-only checks.
Source manifests were not refreshed. These are focused host logging results,
not release, merge, hardware safety or broader staging approval.
