# Error-handling companion for PR #218

Based on contributor head `07601e601b4e1344f05e4f9e3e295b451b03144b` of
[PR #218](https://github.com/windows-GPU-UNLOCK/Windows-GPU-UNLOCK/pull/218).
This is a bounded failure-handling correction, not approval of the benchmark,
the GSP configuration helper or the PR's causal/performance claims.

## Reproduced defect and fix

The original runner reported plausible throughput despite failed allocations,
GEMM calls and synchronization. Its CLI also returned success when every GPU
benchmark raised an exception. Both were reproduced with fake API objects and
a fixed clock; no driver library or GPU was involved.

The companion checks each operation, frees only successfully acquired
resources, attempts all cleanup, and preserves the primary operation failure.
A cleanup failure also prevents returning a successful result. Invalid sizes,
iteration counts and durations are refused. The clock is monotonic, and the CLI
returns nonzero if any device fails or device enumeration fails.

The legacy untyped allocation calls require byte counts that fit a signed C
int. Until the API has complete ABI declarations, matrix dimensions above
23,170 are refused instead of risking truncated allocation sizes.

## Test only, without GPU libraries

```sh
python -m unittest discover -s benchmark -p 'test_quick_*.py' -v
```

The tests mock all driver/library loading and calls. They cover preparation,
each allocation, warmup/timed GEMM and synchronization failures, cleanup,
primary-error preservation, bad parameters/clocks, device enumeration and CLI
failure propagation. A later successful device cannot hide an earlier failure.

Linux/Python 3.12.14 validation: 18 targeted quick-benchmark tests. Native
Windows, CUDA libraries and real GPU workloads were not run.

## Remaining limitations

- Inputs remain uninitialized and there is no numerical reference check.
  Results explicitly carry `reference_checked: false` and the CLI warns about
  this limit. Do not use these timings as correctness or unlock evidence.
- Complete ctypes ABI declarations, CUDA-event timing, DLL discovery/lifetime,
  and a matched before/after protocol need separate review.
- The GSP registry helper and its hardware claims were not changed or verified.
  This work does not authorize changing driver or security settings.

No firmware, hardware, registry or boot operation was performed. Release
manifests were not refreshed. This companion does not replace the project's
existing validated comparison protocol.
