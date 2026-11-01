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
and the mode helper's HandleProtocol refusal branch. CloseProtocol/OpenProtocol
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
