# MSI runtime audit build test

[한국어](CHRISTIAN-RUNTIME-AUDIT.ko.md)

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
