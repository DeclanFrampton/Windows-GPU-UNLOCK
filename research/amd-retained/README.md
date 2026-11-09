# Retained AMD display / two RTX displays experiment

This opt-in build addresses the original B650M-PLUS WIFI BIOS 3057 / RTX 3090 FE
machine when a monitor is connected to the motherboard and two to the RTX.
The headless route refuses an active AMD GOP. The older AMD-preserving route
also refuses a second NVIDIA display child, so changing only the boot entry
does not address this configuration.

`GU_AMD_RETAINED_MULTI_DISPLAY` reuses bounded NVIDIA-child inspection and
sequential EDID release while retaining the AMD GOP, text, input and exact
shared-driver EDID relation. One or two RTX children are accepted; additional
children, duplicate paths, foreign owners and late changes refuse. Dual-child
release remains opt-in. The new switch requires the fixed original
B650M profile and does not qualify LOCAL or other boards/cards.

Compile from a dedicated workspace configured for this exact machine:

```powershell
.\research\amd-retained\build.ps1 -Clang 'C:\TOOLS\LLVM20\bin\clang.exe' -LldLink 'C:\TOOLS\LLVM20\bin\lld-link.exe'
```

This builds manual and automatic wrappers with the existing corresponding
non-headless children. It writes local build outputs only. It does not stage
to an ESP, register/promote boot entries, change Fast Startup or execute EFI.
An existing output is refused; use a new `-BuildName` to retain earlier builds.
This refusal covers the named wrapper output only. The delegated
`internal-boot/Build.ps1` regenerates canonical child outputs and generated
contracts. Use a dedicated workspace or preserve those existing outputs first.
Private local configuration, original code/PROM pins and all runtime guards
remain necessary. The wrapper and child hashes and input hashes are recorded.

`test_amd_retained.c` replays a captured ownership graph through RAM EFI mocks.
Its code and PROM buffers use synthetic pins local to that host translation
unit, with the real SHA-256 implementation. The first 16 PCI dwords come from
the current graph; the remaining capability-chain data come from an explicitly
supplied historical 256-byte fixture. These are not current full-PCI, original
firmware-code/PROM or physical unlock qualification. A successful build/replay
cannot be used as manual-success confirmation or automatic boot promotion.

The manual path releases console/GOP drivers before its later U confirmation.
It is therefore a hardware-changing test even before U. Keep Windows Boot
Manager available and retain the existing headless files and boot recovery.
Physical testing, Windows/display recovery and any deployment are separate
steps after reviewing this experimental package.

## Output changes and recorded hardware result

For the fixed B650M non-headless child, the AMD display ADR payload may vary
within the exact validated ancestry. The complete path is pinned only after a
successful display check and must remain identical throughout that EFI run.
AMD PCI identity, subsystem, BDF, GOP geometry/framebuffer, ownership and all
unlock guards remain required. Headless, LOCAL and other fixed profiles retain
their existing path classification.

On 2026-11-09 the maintainer confirmed a successful manual unlock and Windows
return on the original BIOS 3057 machine with one motherboard display and two
RTX displays. The private build was based on commit
`43f6ac276e671458c95ec3d819af3568fe76d46a` plus the child output-path patch;
its manual wrapper SHA-256 was
`dd9db1cd89e6b8476ad3d709ffcc49f7f4a6c45c0ff126d5467f89b5b4d914f7`
and child SHA-256 was
`1c2fd3a999cd8cc543fab0c5798eb140cc263eb0e614c43be87db0d315d1a4a4`.
The local wrapper and child reports recorded success, one FLR, no retained
mappings, SS0 `0x88888888`, SS1 `0x8` and BME disabled. Raw reports and machine
partition configuration remain private.

This is one manual boot on that source/build combination. It does not establish
repeated-boot stability, performance, support on other machines, or hardware
qualification of the integrated revision. An automatic pair was installed
separately, but its first physical boot remains unverified.

## Host-only child regression checks

With a host Clang/MSVC environment, run in fresh ignored output directories:

```powershell
python -I research/amd-retained/test-child-display.py --clang C:\TOOLS\LLVM20\bin\clang.exe --mutations --output research/amd-retained/build/child-check-1
python -I research/amd-retained/test-child-display.py --clang C:\TOOLS\LLVM20\bin\clang.exe --automatic-ui --output research/amd-retained/build/auto-check-1
```

The tests compile the actual child display gate against RAM mocks, check path
mutation/truncation across B650M, headless and B660M, and require deliberately
broken path/identity guards to fail assertions. Automatic UI tests use synthetic
partition identities when no local configuration is present; they never create
local configuration, access a partition, execute EFI or change boot settings.
