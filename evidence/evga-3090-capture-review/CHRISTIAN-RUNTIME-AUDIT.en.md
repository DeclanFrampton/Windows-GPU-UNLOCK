# MSI runtime audit build test

[한국어](CHRISTIAN-RUNTIME-AUDIT.ko.md)

Christian's saved-input preflight returned all nine checks true. Baseline collection is complete. The next build adds `GU_MSI_RUNTIME_AUDIT` to the generic observation probe. After capture it checks unique loaded DriverBinding/image instances against the two exact MSI console code hashes, versions and Stop RVAs. It logs `msi-text-code-match` and `msi-graphics-code-match`. It never calls Stop or any driver-private method. A code mismatch is recorded as a refusal, not silently treated as qualified release. The generic capture still reads PCI/MMIO/PROM and writes diagnostic files if subsequently booted; it contains no unlock, detach, GPU writes or firmware-variable writes.

`build-christian-audit-package.ps1` is **build-only**. It downloads source revision `2bb452f27ccd56f61e591d5a4a6c0431df96403e` into a fresh `C:\GPU-Unlock\Builds` folder, uses existing LLVM/Python, checks the pinned current system ESP, compiles and verifies the EFI, and packages EFI/manifest/PE verification/source revision under Results. It does not write USB, choose BootNext, mount partitions, execute EFI or reboot. Missing compilers produce an error; install nothing to bypass it. Send the build ZIP for review before staging or booting.

The full source-download/extract/compile/package flow passed locally with only the Get-Partition inventory mocked to Christian's reported GUID. The compiler, PE verifier and packaging ran for real; no hardware test occurred. Local binary: 23552 bytes, SHA256 `c7b3807d88ba86a6a3b6ae448b350dd6b829cd49b12fed67747f3e3f522a3358`, AMD64 EFI, no imports/IAT/delay imports, NX/dynamic-base. Deep workspace paths failed compilation during the first two local fixture runs; a shorter temporary root passed. The default C:\GPU-Unlock path is intentionally short. Different LLVM versions may produce a different binary; review provenance rather than demand byte equality across toolchains.

Runtime admission and controller-release semantics remain separate. This read-only identity audit is not an unlock attempt or a hardware-qualified release build. No user reboot is authorized by the build-only instructions.
