# MSI runtime audit build test

[í•œêµ­ì–´](CHRISTIAN-RUNTIME-AUDIT.ko.md)

Christian's saved-input preflight returned all nine checks true. Baseline collection is complete. The next build adds `GU_MSI_RUNTIME_AUDIT` to the generic observation probe. After capture it checks unique loaded DriverBinding/image instances against the two exact MSI console code hashes, versions and Stop RVAs. It logs `msi-text-code-match` and `msi-graphics-code-match`. It never calls Stop or any driver-private method. A code mismatch is recorded as a refusal, not silently treated as qualified release. The generic capture still reads PCI/MMIO/PROM and writes diagnostic files if subsequently booted; it contains no unlock, detach, GPU writes or firmware-variable writes.

`build-christian-audit-package.ps1` is **build-only**. It downloads source revision `2bb452f27ccd56f61e591d5a4a6c0431df96403e` into a fresh `C:\GPU-Unlock\Builds` folder, uses existing LLVM/Python, checks the pinned current system ESP, compiles and verifies the EFI, and packages EFI/manifest/PE verification/source revision under Results. It does not write USB, choose BootNext, mount partitions, execute EFI or reboot. Missing compilers produce an error; install nothing to bypass it. Send the build ZIP for review before staging or booting.

The full source-download/extract/compile/package flow passed locally with only the Get-Partition inventory mocked to Christian's reported GUID. The compiler, PE verifier and packaging ran for real; no hardware test occurred. Local binary: 23552 bytes, SHA256 `c7b3807d88ba86a6a3b6ae448b350dd6b829cd49b12fed67747f3e3f522a3358`, AMD64 EFI, no imports/IAT/delay imports, NX/dynamic-base. Deep workspace paths failed compilation during the first two local fixture runs; a shorter temporary root passed. The default C:\GPU-Unlock path is intentionally short. Different LLVM versions may produce a different binary; review provenance rather than demand byte equality across toolchains.

Runtime admission and controller-release semantics remain separate. This read-only identity audit is not an unlock attempt or a hardware-qualified release build. No user reboot is authorized by the build-only instructions.

## Reviewed build and attended runtime test (2026-11-01)
Christian returned a 24,064-byte EFI with SHA256
`5db74af86fb1b38385a7868985271d83c155821ba4abdec777bcf698f977ccd0`.
All listed source hashes matched the reviewed source. Independently checked AMD64
and EFI application subsystem; returned PE report records no imports and NX/ASLR.
Different compiler output from the developer build is not a source mismatch.

`research/profile/run-christian-audit.ps1` stages only this exact image on a
FAT32 USB, refuses Windows/system or non-USB disks, backs up the previous EFI
with hash verification and archives existing captures. It verifies USB readback.
`-Mode Collect` packages RTX3090-UNLOCK in C:\GPU-Unlock\Results without deleting
old captures. No automatic reboot or boot-variable changes. Local mock-inventory
checks passed staging, backup, readback, collection and internal-disk refusal;
these do not prove live firmware behavior.

Boot the USB once, attended. Existing generic capture reads PCI/MMIO/PROM and
writes capture files; the new audit reads loaded console code and metadata only.
No Stop callback, reset, DMA, unlock or new GPU writes. Reads/firmware code can
still hang. If Windows has not returned after two minutes, power off, remove
USB and choose normal Windows Boot Manager. Do not retry a failed run; return
captures and say whether Windows started automatically. Recovery is unproven.
The result sought is msi-text-code-match and msi-graphics-code-match in the log,
not an unlock result.

## Live identity result and next method test
DIAG02.TXT SHA256: 0a808399aeb1f1826073670e228f62885dd321ba96a6fb61538749d562ae0142.
Both MSI code-match events and diagnostic-result recorded success. Windows return
was not explicitly described in the reply; do not infer direct handoff from this log.
The returned folder includes three captures, not three executions of this new audit.

The optional MsiZeroChildTest requires the identity audit and exactly one match
for each console implementation. It flushes an enter record, calls only the pinned
text Stop with zero children once, then records its return. This implementation's
zero-child path returned success in 22 emulated instructions without any service
call, global write or controller dereference. All 15 argument cases across the
three captures passed isolated CPU emulation. This does not qualify one-child
removal, the controller-present path, recovery or unlock. No live method test yet.

The new EFI compiled and passed PE checks with partition inventory mocked. A Stop
call is a new live execution boundary even with zero children; unexpected behavior
may hang or affect display/Windows. No automatic retry. Build/package only is
the next handoff; review the returned image before staging this method test.

## Reviewed zero-child package and staging
Returned EFI: 24,576 bytes, SHA256
d5cd327ab59d18436e01461cdaa974db4a2614204c5d47b726b6a466deddfc60.
All manifest source hashes match; AMD64 and EFI subsystem independently checked.
MsiZeroChildTest and CallsDriverStop are true; unlock/detach/firmware writes false.
run-christian-zero-child.ps1 pins that exact image, backs up the previous USB EFI
and captures, verifies readback, and refuses a second staging using a USB marker.
That marker is a staging guard, not an EFI boot-once enforcement mechanism.
Local mocked USB tests passed backup, stage, collection, repeat-stage refusal and
internal-disk refusal. No live zero-child call has run yet. Boot attended once;
no keys are needed. Expected new events: msi-text-zero-child-enter and
msi-text-zero-child-return, both success. If Windows is absent after two minutes,
power off, remove USB and choose normal Windows Boot Manager; do not retry.
Return the christian-zero-child-result ZIP and report automatic/manual return.

## Successful zero-child call and bounded membership observation
DIAG03.TXT records both code identities, zero-child enter/return, and diagnostic
result as success. This proves that invocation returned, not child removal.
The collection screenshot shows an empty drive-letter entry, followed by a
successful retry using G. New commands pass -Drive G explicitly.

The next optional MsiMembershipAudit checks the pinned image globals at 0x6110
and 0x6288 and reads only the first 32-byte controller-list node. It requires
alignment and a containing LoaderData/BootServicesData memory-map descriptor
without read protection; it excludes MMIO and rejects malformed map bounds.
It checks that the child equals ConsoleOutHandle, the next pointer is null,
and the controller exposes GOP with no device path. It never traverses further,
changes these globals, calls Stop or authorizes release. The map is a bounded
read guard, not an atomic snapshot or proof of callback semantics.

The compiled helper passed 13 isolated CPU-emulation cases, including success,
wrong child, multiple nodes, wrong GOP topology, service/log failures, MMIO,
read protection, alignment and malformed map cases. Rejected RAM/MMIO cases
performed zero node reads. The full EFI compiled and passed PE validation.
run-christian-membership.ps1 builds a fixed source snapshot and stages it in one
command, preserving the old EFI/captures. Real download/compile/PE plus mocked
USB backup/readback/collection/repeat-stage/internal-disk checks passed.
No live membership result yet. Boot once attended; capture/firmware RAM reads
can still hang or prevent Windows return. Existing PCI/MMIO/PROM capture reads
remain; no new GPU registers or GPU writes. After two minutes without Windows,
power off, remove USB and select Windows Boot Manager; do not retry.
Return christian-membership-result ZIP from C:\GPU-Unlock\Results.

## DIAG04 and one-shot output-membership removal test
DIAG04 records successful code identities, child-is-console, single-controller,
virtual-GOP-controller and diagnostic result. That is live membership evidence,
not GPU release. The next MsiOneChildTest repeats fresh code/membership checks,
adds exact count=1 and tail=head guards, and calls the pinned output Stop once
with its actual controller and system-console child. It does not call other
text bindings, graphics/NVIDIA Stop, parent Stop, PCI writes or unlock.

Four exact-code emulations with synthetic controller state exercised real unlink
and the mode helper's HandleProtocol refusal branch. CloseProtocol/UninstallMultipleProtocolInterfaces
errors can be ignored by this driver's Stop return, so success alone is insufficient.
These emulations do not qualify all mode rebuilding or live firmware callbacks.
Compiled membership guards passed 15 synthetic cases. The full EFI passed PE
checks; full download/build and mocked USB stage/backup/collect/refusal checks passed.

Before invocation the EFI disables its firmware watchdog, consumes the arm file
and flushes an enter log. It suppresses further console output. Afterwards it
requires a successful Stop return, count/head/tail all zero, and absence of this
binding's BY_DRIVER/BY_CHILD opens on the old controller's text-output protocol.
Every recorded check must pass before Windows; errors hold without reset or
BootOrder fallback. Arm consumption prevents another removal call unless a new
arm is manually created; the script refuses existing staged/armed markers.
No automatic rollback/rearm exists. Unexpected firmware side effects, hangs,
display/input loss or Windows failure remain possible; recovery is unproven.

run-christian-one-child.ps1 -Drive G -AcceptRisk builds and stages; -Mode Collect
packages christian-one-child-result under C:\GPU-Unlock\Results. Run attended
once. If Windows is absent after two minutes, power off, remove USB and choose
normal Windows Boot Manager. Do not repeat. No live one-child result yet.

## DIAG05 successful membership removal and virtual renderer test
DIAG05 records consumed arm, exact code guards, correct membership, successful
one-child return, empty list, closed text ownership and diagnostic success.
This establishes one live output-membership removal, not NVIDIA/GPU release.
Correction: boot-service offset 0x150 is UninstallMultipleProtocolInterfaces,
not OpenProtocol. Prior emulation notes naming that service were corrected.
The ignored-error finding remains valid for CloseProtocol and uninstall calls.

The next test repeats that proven removal, then calls the sole virtual GOP text
renderer Stop with zero children. Its exact MSI IMG16 executable section is
RVA0x2a0, 7232 bytes, SHA256
654ca7fec19bf03dabe804d0d81d47dc810788be59dea03d8c24c727281494ac;
Stop RVA0xa08, version16, image size0x39a0. Five isolated emulated service cases
passed: success, refused open, refused uninstall, ignored close failure and
ignored pool-free failure. This is not proof of actual protocol callbacks.
Fresh code uniqueness and exact GOP owner checks precede mutation. Afterwards
GOP ownership must be gone, text-output/private interfaces must be unlisted and
GOP must remain listed once. UGA and graphics/NVIDIA release are not qualified.
The list guard now also requires a null previous link; 16 compiled guard cases
passed. EFI compile/PE and complete fixed-source download/build plus simulated
USB backup/readback/collection/refusal tests passed. No live renderer test yet.

run-christian-virtual-text.ps1 -Drive G -AcceptRisk builds/stages and creates
MSI-VIRTUAL-TEXT.ARMED, consumed before the sequence. It adds removal of text
interfaces and freeing renderer buffers. Display/input loss, firmware hang and
Windows failure are possible. No reset, PCI writes, graphics/NVIDIA Stop, unlock
or automatic restoration is added. Hold on any failed check; after two minutes
without Windows, power off, remove USB and use normal Windows Boot Manager.
Do not retry. Collect returns christian-virtual-text-result ZIP under Results.

## DIAG06 renderer success and graphics membership test
DIAG06 records successful repeated output membership removal and virtual-renderer
Stop, closed GOP ownership and unlisted text/private interfaces. Diagnostic result
is success. This is two live console-consumer removal stages, not GPU unlock.

The next MsiGraphicsTest repeats those stages and calls the exact pinned graphics
Stop once with the physical controller and virtual GOP child. Fresh code plus
allocated-RAM guards require one controller, null forward/back links, exact tail,
child equality, and payload equality with the physical GOP interface. Cached mode
nodes are limited to 64 and checked for consistent forward/back links and tail.
The plan and physical GOP BY_DRIVER/BY_CHILD ownership are checked again after
text removal. Stop's last-controller path frees modes and attempts a framebuffer
copy through the existing firmware GOP Blt method. This is new firmware execution;
the copy and real side effects are unproven. No direct GPU register transaction,
PCI writes, NVIDIA/parent Stop, ResetSystem or unlock code is added.

Nineteen compiled graphics-plan cases and seven exact-driver synthetic cases
passed isolated CPU emulation. The real driver code, including its snapshot
helper, ran only against mocked services/Blt. It can return success after ignored
allocation, close, free and Blt errors. The EFI separately requires empty
controller count/head/tail, removed GOP ownership and an allocated snapshot
buffer; buffer presence is NOT proof the copy succeeded. Failed checks hold.
EFI compile/PE plus full fixed-source download/build and simulated USB backup,
readback, collection and refusal checks passed. No live graphics result yet.

run-christian-graphics.ps1 -Drive G -AcceptRisk uses a new consumed arm file,
MSI-GRAPHICS.ARMED. It may change/freeze display, lose input, hang or prevent
Windows boot; recovery is unproven and no automatic restoration exists. Boot
once attended; after two minutes without Windows, power off, remove USB and
select normal Windows Boot Manager. Do not retry. Collect packages
christian-graphics-result under C:\GPU-Unlock\Results.

## DIAG07 graphics membership success and EDID/NVIDIA metadata test
DIAG07 records successful prior text stages, fresh graphics plan, graphics Stop
return, empty controller list, closed GOP ownership and allocated snapshot buffer.
Diagnostic result is success. This proves the checked membership transition and
allocation, not framebuffer-copy correctness, NVIDIA release or unlock.

Christian has one EDID-discovered handle on the physical GOP, not the EVGA test
machine's three. Its consumer is IMG07, image0x9000, version1, Stop0x149c, code
RVA0x1000/14178 bytes, SHA256
333b27054df5e7d197238b860fe04e8e618712b533d1608ee9056e1b2435fcb2.
The next MsiEdidTest repeats the proven sequence, then invokes this one consumer
Stop with zero children. Exact code plus unique EDID ownership is required before
any mutation and again before this call. Afterwards its ownership must be gone
and the driver's flag at0x5501 must be zero. Normal EDID-present success and
close-error branches passed isolated emulation. A failing first OpenProtocol
reaches alternate firmware paths; the emulator detected that boundary but did
not execute/qualify those paths. Real behavior remains an explicit risk.

The same boot audits NVIDIA code and protocol metadata before/after: exact
nvgop-ga1xx image0x2b700, version0x60009, Stop0x698, codeRVA0x280/146818 bytes,
SHA256 d045cee2113e461c7c678ec21542b1d0f18356765c0fc6a0bf2dcf824088e011.
The audit requires a unique parent DevicePath BY_CHILD relation to the physical
GOP and matching PCI_IO BY_DRIVER ownership. It calls no NVIDIA Stop and reads
no new GPU MMIO registers or PCI config offsets. These observations do not qualify
NVIDIA callback semantics or authorize unlock. Compiled metadata helpers passed
10 EDID and8 NVIDIA synthetic cases. EFI PE plus fixed-source download/build and
simulated USB backup/readback/collection/refusal passed. No live EDID result yet.

run-christian-edid.ps1 -Drive G -AcceptRisk uses consumed MSI-EDID.ARMED. The new
firmware Stop may take unqualified fallback paths, affect display/input, hang or
prevent Windows boot. Recovery remains unproven; no automatic rollback/retry.
Boot once attended, no keys. After two minutes without Windows, power off,
remove USB and choose normal Windows Boot Manager. Do not rearm. Collect returns
christian-edid-result ZIP in C:\GPU-Unlock\Results.

## DIAG08 EDID success and combined NVIDIA child/parent release
DIAG08 records successful EDID Stop, closed EDID ownership, cleared driver flag,
both NVIDIA metadata audits and diagnostic result. This establishes the four
consumer stages. NVIDIA teardown and unlock remain unproven on this MSI card.

The optional MsiNvidiaRelease repeats those stages, then calls the pinned NVIDIA
Stop once with the single physical child. Only successful post-checks permit one
parent Stop with zero children. This is the same exact NVIDIA code as the prior
EVGA path; different child topology and hardware still require live validation.
Before mutation and immediately before child Stop, the private interface must
reside in bounded allocated RAM, store this physical child at0x88 and have flag
0x98 zero. The flagged parent callback branch is therefore refused.

Child postconditions require only the software virtual GOP (zero framebuffer),
no EDID handles, the physical child handle absent, no parent DevicePath child
opens, retained NVIDIA PCI ownership, and a null stored child/zero flag. Parent
postconditions recheck the console topology, require private-interface absence
and no NVIDIA parent ownership, and read PCI config offsets0..0x3c to verify
10de:2204/subsystem38811462/class3. msi-nvidia-pci-command-value stores raw command
data in its status field, not a UEFI operation result; decoding state is measured,
not presumed. No code re-enables attributes or performs an unlock transaction.

Eleven compiled private-context and nine ownership guard cases passed CPU
emulation. Five limited exact-driver dispatcher paths also passed; an empty
synthetic parent context and refusal paths do not qualify real GPU teardown
callbacks. Full EFI compile/PE and fixed-source download/build plus simulated
USB backup/readback/collection/refusal checks passed. Live child/parent teardown,
hardware side effects and recovery remain unproven on Christian's machine.

run-christian-nvidia-release.ps1 -Drive G -AcceptRisk consumes a new
MSI-NVIDIA-RELEASE.ARMED before the sequence. NVIDIA callbacks may change GPU/PCI
state, disable I/O/memory decoding, bus mastering and VGA, lose display/input,
hang or prevent Windows boot. There is no automatic restoration/retry. Any
failed check holds, and no explicit ResetSystem is added. Boot once attended.
After two minutes without Windows, power off, remove USB and choose normal
Windows Boot Manager. Do not rearm. Collect produces christian-nvidia-release-result
ZIP under C:\GPU-Unlock\Results. This test still does not attempt unlock.

## DIAG09 NVIDIA release success and bounded cold-state test
DIAG09 records both NVIDIA Stop returns and child/parent postconditions as success.
The measured post-parent PCI command value is0. The physical child/EDID handles
are absent, the private interface is gone and NVIDIA ownership is released.
This is live teardown evidence, not unlock or general recovery proof.

The next MsiColdProbe repeats the release sequence, claims PCI_IO exclusively,
requires command0 and no I/O/memory/BME/VGA decode attributes, checks BAR0's
16MiB resource against its PCI BAR, then enables MEMORY only (0x200). It requires
command2 and exactly saved|MEMORY attributes. No I/O, BME or VGA enable is added.
It reads chip0 twice, eight fixed Ampere registers twice (0x118128,0x118234,
0x110100,0x1fa828,0x823804,0x82381c,0x823820,0x1183a4), and the512-byte PROM
prefix at0x300000..0x3001fc once:146 DWORD accesses total. The prefix must match
SHA25673ae5e75a576f5dbbf90e7351aac055b7a9b6a249274f7ded03b33c7740d13c8.
This is not a full cold-ROM dump or firmware execution. SS0 and other register
values are observations; they are not pinned across boots or required stable
within this observation test. All-ones/BADF sentinels hold.

Only normal completion disables MEMORY again, verifies command0 and the exact
saved attributes twice, closes exclusive ownership and rechecks the parent.
No further BAR0 reads occur after Disable. Errors hold without speculative
rollback; memory decode can remain enabled until manual recovery. Value-suffixed
events store raw data in the status field, not operation results.

Seventeen compiled-helper emulator cases passed, including success with146
reads, volatile SS0, admission/attribute/BAR/MMIO/hash/log/restore/ownership
failures. They verify software ordering, not live MMIO safety or recovery.
The real EFI passed compile/PE and fixed-source download/build plus simulated
USB backup/readback/collection/refusal checks. No live cold-state result yet.

run-christian-cold-probe.ps1 -Drive G -AcceptRisk uses consumed
MSI-COLD-PROBE.ARMED. New PCI decode changes/MMIO reads may have side effects,
hang firmware or fail display/input/Windows. No GPU MMIO writes, DMA launch,
firmware upload/execution or unlock transaction is added. Boot once attended.
After two minutes without Windows, power off, remove USB and choose normal
Windows Boot Manager. Do not retry/rearm. Collect returns christian-cold-result
ZIP under C:\GPU-Unlock\Results.

## 2026-11-01: live cold prefix passed; full cold PROM comparison

Christian returned `christian-cold-result-7ec09cc47269437bb41c507f9e995e5b.zip`.
`DIAG10.TXT` SHA256 `de8637614928cfb61aead1142db9bda6ae29d5daa5da037cb47aca38acc0c09c`
records all prior stops, exclusive claim, memory-only enable, both eight-register
passes, prefix match, chip checks, memory disable, two saved-state checks,
exclusive release, final parent post-check and diagnostic-result succeeding.
Chip was `b72000a1`; BAR0 `91000000`, length `01000000`; attributes 0 -> 200 -> 0.
Both SS0 observations were `30232144`; this does not establish cross-boot stability.
The initialized PROM still hashes to `de78e145e527059faec711a9a320b6dca6a88dc4de0fed882d1688ba2dd1aad1`.
No unlock transaction ran. Direct Windows return is assumed under the reporting
convention unless Christian reports otherwise; the log alone does not prove it.

The next optional `-MsiColdFullProm` stage repeats the complete proven sequence,
expanding the post-release PROM read to the fixed 1 MiB window 300000..3ffffc.
It hashes that snapshot against the recorded initialized PROM, without saving or
executing it. Cold phase: 262144 PROM DWORD reads + 16 register + 2 chip reads =
262162 accesses. This count excludes the unchanged pre-release generic capture.
The original 512-byte mode remains available. A static BSS buffer avoids a 1 MiB
firmware stack allocation. Normal completion uses the same memory-disable,
exact saved-state checks and ownership release, with no MMIO after disable.
An unexpected result still holds without automatic rollback; expanded live reads
can hang or have side effects, and manual power-off/USB removal may be required.
No new GPU MMIO writes, DMA, firmware upload/execution, reset or unlock is added.

Validation: the compiled full-PROM helper with actual SHA256 passed success (262162 reads), first-byte corruption and last-DWORD corruption cases. Both mismatch cases held with decoding enabled, as designed; they do not prove recovery. The rebuilt 512-byte helper passed all 17 regression cases. The full EFI compiled and passed AMD64 EFI PE checks (37376 bytes; SHA256 ce4b90b292e311b2a0ddf3a98fe5e1b8bae2a685791744fb21bb9ef1b4c904e9). These are software/emulated checks, not a live full-cold-PROM result. Event names retain prom-prefix for compatibility; the full-mode build manifest identifies the 1 MiB comparison.

## 2026-11-01: complete cold PROM matched; prepare transaction payloads

Returned archive `christian-cold-full-prom-result-e5e2e25a6d644a6d8beaa4f3bbef0e3d.zip`
contains DIAG11 SHA256 `975df662493236986e209a274d0927f6961cc3a4fcfa8f10a13dd94299b5b061`.
The full-mode stage receipt pins source 4c2b7e140c9793bdcf083680dd462d3b4f4bd2d2.
All release, full 1 MiB hash comparison, decode-off, saved-state, ownership and
final parent checks passed. SS0 is now 70232144, versus 30232144 in DIAG10;
therefore a fixed cross-boot SS0 value would reject this otherwise passing run.
Keep an immutable per-attempt entry reference for a future transaction; do not
weaken the expected transition checks. No unlock has run. Windows return follows
the existing reporting convention, not a new log-only proof.

The next runnable step is Windows-only `prepare-christian-assets.ps1`: prepare
and verify the five pinned GA102 payloads using the existing provenance-checked
asset generator, retain licensing notices locally, and return only a hash/size
report ZIP. Defaults: C:\GPU-Unlock\Assets\ga102 and C:\GPU-Unlock\Results.
It neither touches USB nor stages an EFI, accesses the GPU, runs firmware or
reboots. Existing directories are verified rather than regenerated; partial or
mismatched output is refused. This supplies actual transaction prerequisites
while the MSI-specific transaction adapter remains unfinished; the EVGA adapter
cannot be reused unchanged because its subsystem, BAR base and PROM differ.

Local validation passed both an existing verified payload directory and a fresh upstream clone/download/extraction/generation run using Python 3.14. A deliberately corrupted descriptor was refused. Report ZIP inspection confirmed one JSON file with five asset records and no firmware. This validates Windows preparation only, not firmware behavior or MSI unlock.

## Python preparation compatibility correction

Christian reported the deliberate Python 3.14 refusal and correctly stopped
before installing anything. The preparation launcher now accepts Python 3.12+
and uses a private virtual environment for 3.12/3.13 only when generating new
payloads. It installs zstandard 0.25.0 with exact official PyPI Windows x64 wheel
SHA256 pins and no dependencies; global Python packages, PATH and registry are
not changed. Existing payload verification needs no decompressor installation.
Python 3.14 retains native zstd decoding. The shared generator keeps pinned
upstream parsing and final payload identity checks; only decompression differs.
No USB/GPU/EFI/reboot action is introduced. If preparation fails, keep its files
and report the error instead of changing Python installations speculatively.

Official wheel metadata: https://pypi.org/pypi/zstandard/0.25.0/json
Windows cp312 SHA256 ffef5a74088f1e09947aecf91011136665152e0b4b359c42be3373897fb39b01;
cp313 SHA256 1f830a0dac88719af0ae43b8b2d6aef487d437036468ef3c2ea59c51f9d55fd5.
Compiled-code behavior and live unlock remain outside this preparation step.

Validation: Python 3.13.15 passed complete fresh preparation through the actual launcher: pinned source download, private environment creation, hash-checked wheel installation, upstream clone/download/extraction and all five final payload hashes, then report ZIP generation. Direct fallback generation also passed. Python compile and PowerShell parse passed. The two wheel hashes were checked against official PyPI metadata. Python 3.12 compatibility is implemented but not executed in this check; prior native 3.14 validation remains separate.

## Git-free preparation correction

Christian's next screenshot confirms Python 3.13 and the pinned zstd helper
installation succeeded; the next refusal was Git not found. The launcher now
fetches the exact upstream source ZIP instead of requiring Git. Before any
extraction or importing downloaded code, the generator requires archive SHA256
`d0d8ecd989f9cb885d8eb9ab39fb3f36c9c66df2efd9fabaa68f8afc8bbe70fb`
from `https://github.com/Zagitta/gpu-unlock/archive/0ebdb1c6308b6a2072be5bf04513472942541956.zip`.
Extraction uses a new directory; an altered archive is refused before extraction
or output creation. The existing clone-based developer path remains available.
Pinned NVIDIA input hashes, parsing, five payload output hashes and licensing
checks remain unchanged. An upstream archive regeneration that changes bytes
will refuse rather than silently execute different source. No global Git install,
USB changes, GPU access or reboot is needed.

Validation passed a complete fresh launcher run with Git deliberately absent from PATH: Python 3.13 private environment, pinned wheel, source ZIP download/hash/extraction, input download, payload generation and five hashes, then report ZIP. A modified source ZIP was rejected before either source/output directory creation. Python compile and PowerShell parse passed. Direct source-ZIP generation passed separately. This is software preparation evidence only.

## Incomplete preparation can now return a report

Christian reported no result ZIP. His screenshot ends after successful helper
installation, without a returned PowerShell prompt or shown error. It does not
establish a preparation failure or completion: the existing launcher creates
its ZIP only after downloads, extraction, generation and verification finish.

New `collect-christian-assets.ps1` independently collects current presence,
size/hash checks, notice presence and bounded preparation-directory metadata.
It produces a report-only Results ZIP even when all payloads are missing or
partial. It does not rerun preparation, install packages, download anything,
access GPU/USB, arm a run or reboot. Its preparation_complete flag describes
only the snapshot at collection, not EFI readiness or unlock. Run in a second
PowerShell window if the original preparation is still busy; do not relaunch it.
Local checks passed absent, fully verified and corrupt/partial payload cases;
all three ZIPs contained one report JSON and no firmware. Only the fully
verified case reported completion. Existing raw payloads were unchanged.

## 2026-11-01: preparation report returned; download/process visibility added

Christian returned `christian-assets-result-7ff7ea5d2e31453a81d8391e4a513c2f.zip`.
Its report says preparation_complete=false, all five outputs and both notices
missing. Recent build directories contain the source ZIP, upstream ZIP and
private Python environment. This does not identify the download/extraction
boundary, prove an active worker, or justify restarting preparation.

Collector v2 adds two samples two seconds apart of bounded known input-cache
file names/sizes/timestamps and matching preparation Python process IDs, CPU
time and working set. It never exports command lines, download contents,
endpoints or unrelated process metadata. Process-inventory failure is explicit.
No process is stopped; preparation is not retried; no GPU/USB/firmware action.
The samples help distinguish pending download from later work, but a two-second
unchanged sample alone cannot prove a hang. Tests passed a partial-download
fixture with mocked process CPU data, JSON-only ZIP/privacy checks, and actual
Windows PowerShell 5.1 collection against verified assets with real CIM inventory.

## 2026-11-01: cached inputs available; finish without redownloading payloads

Christian's v2 report `christian-assets-result-5031a94e41f74825ae5f3af1a9f66013.zip`
shows no matching preparation workers and no inventory error at either sample.
One attempt retains the complete named 314789539-byte package plus the
26172192-byte source archive; a later attempt retains a 279969792-byte partial
file unchanged since 19:30. File sizes do not prove input authenticity, and the
original reason preparation ended is still unknown. Preserve both attempts.

`finish-christian-assets.ps1` now discovers existing prepared Python and complete
named cache inputs. The shared generator's --input-cache mode verifies pinned
input hashes offline and refuses missing/invalid data without replacement
downloads. The finalizer rechecks active workers and refuses overlap; it does
not kill processes. It verifies the upstream ZIP hash, extracts into a fresh
work directory and generates payloads using the complete cache. Existing
nonempty output is verified rather than overwritten. It always attempts a
report/log ZIP on ordinary preparation errors, keeping firmware out of it.
Only the small pinned repository source ZIP is downloaded, not NVIDIA inputs.
No packages, Git, Python upgrade, GPU access, EFI staging or reboot is involved.

Validation passed actual offline generation from the complete pinned cache, Windows PowerShell 5.1 finalization into a fresh output directory, existing-output verification, missing-input failure reporting and an active-worker refusal fixture. ZIP inspection confirmed report/log only and five verified assets on success. No worker was stopped, cached inputs were not overwritten, and no EFI/hardware execution occurred.

## 2026-11-01: Windows payload verification passed; combined EFI resource test

Christian returned `christian-assets-finish-90fa54d505ee43129b813162f2742b38.zip`
(archive SHA256 bc4602e7e1ff99ee899ea7ac8e05414948ae4d2d89008481296d2b9bf23db150).
The report has preparation_complete=true, no error and all five expected sizes
and SHA256 values. It used the complete existing cache with no payload download.
This proves Windows file preparation, not EFI loading or unlock execution.

New optional -MsiAssetsDma combines the remaining payload-residency and host
common-buffer checks with the already demonstrated release/full-PROM/decode-off
sequence. After consuming the one-shot marker, EFI reads and hashes all five
USB payloads (84427316 CPU bytes), retaining them through the resource checks.
No payload is uploaded or executed. After cold reads, with exclusive ownership,
command2 and memory-only attributes, it allocates 20576 pages (84279296 bytes),
maps them once with BusMasterCommonBuffer, requires an aligned nonzero complete
32-bit device range, rechecks BME/IO/VGA remain off, then unmaps and frees.
It does not launch DMA, enable BME, reset or unlock. This qualifies one mapping,
not GPU DMA behavior or the complete transaction's allocation pattern.

Normal completion follows existing memory-disable, saved-state and ownership
checks, then frees the five CPU payloads before Windows. Errors hold without
automatic rollback; CPU buffers or mappings may remain allocated and memory
decoding enabled until manual recovery. Firmware allocation/mapping may hang
or fail display/input/Windows. Recovery is unproven. Attend one boot only;
after five minutes without Windows, power off, remove USB, select normal
Windows Boot Manager. Do not repeat/rearm. The staging script verifies local
and USB payload hashes, preserves backups, and excludes ASSETS from result ZIPs.
The 262162 cold MMIO read count is unchanged; no new GPU MMIO addresses/writes.

Validation: eight compiled helper cases passed with the real SHA256 and full 262162 cold reads: success, allocation failure, map failure, short/high mapping, unexpected mapped BME, unmap and free failures. Four mocked payload-lifetime cases and six actual reader/hash-vector cases passed; the existing 17 prefix regressions passed. EFI compiled/linked and passed PE checks: 40448 bytes, SHA256 e4f98d2026b5846226555b989a920129a83df72cb5434fa6134adaaab9b3156f, AMD64 EFI, zero imports/IAT/delay imports, NX/ASLR. Fixed-source download/build plus simulated USB backup, all payload hash readbacks, collection, repeat and internal-disk refusal passed. Returned ZIP inspection confirmed ASSETS exclusion. These are software/mocked checks, not live common-buffer or recovery proof.

## 2026-11-01: live payload/common-buffer stage passed; exact admission preflight

`christian-assets-dma-result-532e8f115cce402da7d15cd236e47866.zip` contains DIAG12
SHA256 f72fa99df1daac2c28f84540e0447ffcbd779ff88343c01698cdb8a5896d4208.
All five EFI payload checks and releases, common-buffer allocation/map/state/
unmap/free checks, cold PROM, decode-off, exact saved-state and final parent
checks passed. The mapped device address was 7b48c000 for 05060000 bytes. No
payload was executed, DMA launched or unlock attempted. One mapping succeeds
on this run; it does not prove future transaction allocations or GPU execution.

New optional -MsiAdmission adds a CPU-only exact admission rule in
internal-boot/unlock/msi-admission.h: MSI 2204:38811462, bus1/function0, BAR0
91000000, captured PROM hash, bounded valid PM/PCIe/MSI capability chain, command2,
FLR capability and inactive MSI, exact known cold engine/feature/memory values.
SS0 is checked for supported stock values, not pinned across boots. The first
cold batch is retained as an immutable per-attempt reference. The second batch
and a final nine-read sample after mapping must match it; an unexpected change
holds rather than overwriting that reference. Fresh location and 256-byte PCI
config are checked before reporting msi-exact-profile-admission.

The preflight does not invoke a transaction or authorize GPU writes. It repeats
the proven payload/mapping path, adding nine reads at existing GPU addresses
(262171 cold reads total) and fresh PCI reads. Normal completion keeps the same
decode-off/ownership/payload release and Windows route. A new guard refusal can
hold; recovery remains unproven. No new GPU MMIO address/write, reset, DMA launch
or firmware execution is added. The MSI transaction adapter remains unfinished.
