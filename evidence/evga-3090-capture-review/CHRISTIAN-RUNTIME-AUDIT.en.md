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
