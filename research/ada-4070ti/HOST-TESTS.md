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

## Baseline execution checkpoint

The baseline has now run on Windows using MSVC 14.29.30133 (VS 2019 Build Tools).
[run_host_tests.py](run_host_tests.py) verifies 68 upstream file hashes against
[host-source-provenance.json](host-source-provenance.json), then compiles three
ordinary console programs. It does not invoke upstream build/install scripts.

| Program | Observed result |
|---|---|
| Diagnostic application with fake UEFI services | 5,530 checks passed |
| Platform graph and loaded-image parser mocks | 179 checks passed |
| VBIOS/FWSEC parser with synthetic fixture | Passed, including every length 0–4095, valid expansion-chain variants and malformed ranges |

[baseline-host-results.json](baseline-host-results.json) preserves the local
compiler version, results and executable hashes. Hashes identify this run's
artifacts, not a promise of reproducible MSVC binaries. Upstream's printed phrase
"full EFI application executed against host mocks" describes calling `UefiMain`
inside a normal console test; no EFI image was produced or executed by firmware.
The parser test's optional real-ROM argument was not supplied. Its patch routine
operates only on synthetic in-process arrays.

Reproduce with a separately obtained checkout of the pinned fork:

```powershell
python research/ada-4070ti/run_host_tests.py ../gpu-unlock-ada-research `
  --vcvars 'C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvars64.bat'
```

Builds use `/W4 /WX`, assertions enabled. The Linux parser fixture needs explicit
MSVC warning exemptions for byte narrowing (4244), unsigned checksum negation
(4146) and an optional integration variable shadow (4456). The diagnostic tests
do not use these exemptions. VS 18's setup script failed on this installation;
the working VS 2019 environment was used without changing either installation.
Initial compiler-environment quoting was corrected before the successful run.

The runner writes artifacts/capture/logs only under this folder's ignored
`build/` tree. All services in the application test are fake function pointers;
no Windows device handles, driver loading, MMIO or PCI access is performed.
