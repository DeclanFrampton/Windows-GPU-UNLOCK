# Ownership query regression (host RAM only)

Run from the repository root with an existing GCC-compatible host compiler:

```sh
experimental/tests/run_ownership.sh
SANITIZE=1 experimental/tests/run_ownership.sh
```

The harness explicitly refuses compilation unless `__STDC_HOSTED__ == 1`.
The runner checks that `-ffreestanding` fails with the intended harness diagnostic.

The harness includes the actual `experimental/src/unlock_engine.c` and calls its
static `CheckGpuDisplayAndOwnershipOk` predicate. Production headers and build
selection defines are retained; `--gc-sections` removes the uncalled execution
engine. Only mock PCI command reads, protocol queries, pool frees and logging
are reachable. All other boot-service/PCI callback pointers are null. The
runner also rejects surviving engine, Gu*, or vendor-transaction symbols using
`nm`. It builds ordinary hosted executables in a temporary directory, not EFI
images, and does not use firmware inputs, device access, or compiler installs.

The baseline source is read from commit
`a5b3535a538c7e8f76e849a3f84c3864c94fddcf`, not a copied model. The baseline mode
reproduces acceptance of resource/device errors and a missing nonempty owner
list. Running corrected expectations against that source must fail. The fixed
source passes 33 cases, including PCI/display guards, errors, a warning,
null output, a valid empty allocation, allowed entries, driver/exclusive owners,
and oversized counts. The 4096-entry case verifies the last owner is checked.

## API and cleanup policy

[UEFI 2.10 section 7.3.11](https://uefi.org/specs/UEFI/2.10_A/07_Services_Boot_Services.html#efi-boot-services-openprotocolinformation)
specifies an allocated `EntryBuffer` on `EFI_SUCCESS` and caller cleanup through
`FreePool`. Only `EFI_SUCCESS` establishes a successful query; warnings are not
specified successes. The vendored `Include/Uefi/UefiSpec.h` declaration agrees.
[EDK2 CoreOpenProtocolInformation](https://github.com/tianocore/edk2/blob/master/MdeModulePkg/Core/Dxe/Hand/Handle.c)
also allocates one entry even when the owner count is zero. Therefore a
successful non-null/zero-count result is accepted and freed, while a successful
null result is rejected even when count is zero. The 4096-entry scan ceiling is
a defensive application limit, not a claimed UEFI constraint. Larger lists are
rejected and freed before inspecting any entry, never partially accepted.

Every non-null successful query result is passed to `FreePool` exactly once,
including rejected driver and oversized-list cases. Non-success outputs do not
establish a valid allocation: they are neither dereferenced nor freed. Poison
output tests enforce that rule. The mock free uses a RAM fixture and checks
ownership/call count; it does not model the firmware allocator. The pre-existing
policy of ignoring `FreePool`'s return status is unchanged. Sanitizers check
host memory accesses/undefined behavior only; LeakSanitizer is explicitly
disabled and no firmware allocation/leak-free claim is made.

## Limits

This is a predicate regression, not a full-engine integration test. The hosted
compiler uses the host ABI; this does not validate firmware EFIAPI calling
conventions. ASan/UBSan checks do not include LeakSanitizer. Zero real
hardware/transaction calls are guaranteed by the hosted binary's limited linked
code and mock callbacks, not by executing the full pipeline. In production,
`ExecuteGpuRamUnlock` still normalizes PCI and reads selectors before this gate;
this patch does not move that work or establish ownership acquisition. It does
not address the console, USB staging, registry restoration, profile admission,
or other review findings. It does not validate hardware safety, UEFI boot,
Windows unlock behavior, recovery, or shipped binary reproducibility. No EFI
build, hardware run, installation, publication, or deployment is part of this
regression.
