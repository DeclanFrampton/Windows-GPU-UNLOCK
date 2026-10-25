# AD104 diagnostic and parser: host-only investigation

Source under study: external `gpu-unlock-ada` commit
`4e7fefcc4923f9e083d5324dc75a7d2f906af77f`.
Date: 2026-10-25. No GPU access or firmware execution is authorized by this work.

## Finding 1: the diagnostic is also an exact-platform sampler

`windows/ad104-msi/diagnostic/src/sample.c:CaptureGuard` requires the captured
card revision, PCI location `0000:01:00.0`, BAR0 `0x80000000`, a matching 16 MiB
resource descriptor and memory decode on with bus mastering off. It does not
discover arbitrary BDF/BAR locations before its MMIO reads. Consequently a
diagnostic capture may enumerate our matching GPU while refusing the deeper
register/PROM sample. This is a source-derived expectation, not an observed
rejection on our B550 host.

The host test suite already covers failed guards, early read failure and PCI
identity drift. PROM tests cover a bad signature and one mid-stream read failure.
Additional useful cases are failure/drift at the final identity check and ROM
signature changes during the copy. These can be simulated entirely in RAM.

## Finding 2: graph completeness is not evidence completeness

`diagnostic/src/platform.c:SamplePlatform` marks enumeration/API/budget failures
in `complete`. Driver-binding/image lookup failures and unavailable code details
are represented separately; a successful graph walk can still have missing code.
It always emits `atomic_snapshot:false` and `release_authorized:false`.
Consumers must check the required fields individually; neither `complete:true`
nor a code hash can authorize display release. We will characterize missing
target/owner IDs and malformed loaded-code cases with synthetic handles.

## Execution boundary and status

The planned runner compiles ordinary Windows console executables with mocked
UEFI services and synthetic ROM arrays. It will not invoke either upstream
`Build.ps1`, produce an EFI, install/load a driver or use a device interface.
ROM patch tests, if exercised, modify synthetic process memory only. External
source remains pinned and unmodified. Build artifacts stay in an ignored local
`build/` directory; only research sources, summaries and hashes are committed.

This first checkpoint records source inspection only. Test execution and results
will be appended in a later commit after the host binaries have actually run.
