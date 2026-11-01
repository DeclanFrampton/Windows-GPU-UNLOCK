# MSI reusable installer preparation

The exact attended USB unlock and same-boot tensor uplift are demonstrated.
The new payload package and local installation-state preparation are locally
validated, not hardware-qualified reusable installation. Nothing here enables
permanent, unattended, shared-ESP or automatic rearm operation.

## Build and prepare locally

In the matching source checkout, run:

```powershell
& .\research\profile\build-msi-profile.ps1 -OutputDirectory C:\GPU-Unlock\Packages\MSI-01
& .\research\profile\test-msi-package.ps1 -PackageDirectory C:\GPU-Unlock\Packages\MSI-01
& .\research\profile\prepare-msi-install.ps1 -PackageDirectory C:\GPU-Unlock\Packages\MSI-01
```

The builder uses the existing exact MSI write adapter and Windows ESP pin. It
creates an EFI/profile/source/PE/license inventory and ZIP. The local preparer
checks every file's size/hash, profile and build policy, then copies the package
into a fresh C:\GPU-Unlock\MSI-Profile state directory. installation-plan.json is
explicitly PreparedNotInstalled. NVIDIA assets are not bundled. No arm marker,
USB/ESP write, firmware variable, boot entry, scheduled task or restart is made.
Existing state is preserved and refused; do not delete it to bypass a refusal.
Use a fresh directory for a new reviewable preparation.

## Attended rearm implementation next

The current EFI consumes a fixed MSI-UNLOCK.ARMED marker; its in-memory spent
flag lasts one invocation. That is sufficient for the tested one-shot handoff,
not durable reusable attempt identity. Do not teach the installer to recreate
that fixed marker or erase MSI-UNLOCK.STAGED.

1. Give each build/run a unique identity and immutable package/image/asset hashes.
2. Before any lifecycle/MMIO action, durably create and flush a STARTED receipt,
   consume the exact matching arm and verify its readback. Missing, mismatched,
   pending or failed receipts forbid another execution.
3. Write a separate FINISHED receipt only after transaction containment, target
   verification, decode-off, ownership release and payload release all succeed.
4. The Windows controller checks the exact prior package and receipts plus the
   contributor's Windows return; keeps originals and backs up only owned files.
   A new attended choice creates a new identity, never recreates old authorization.
5. Validate install/cancel/collection/restore, interrupted writes and every
   pending/failed-state refusal locally before one informed hardware rearm.

## Unattended boot and persistence

Unattended unlock means running the guarded transaction on selected boots; it
does not make a hardware change permanent. Do not add a task that recreates arm
markers or silently retries. First qualify the attended reusable path, then
review a bounded opt-in boot policy with an attempt budget, durable failure
latch, normal Windows handoff and an explicit disable/restore path. Internal
ESP layouts need separate identity, source-device, log/asset and restoration
qualification; the EVGA profile cannot be substituted for MSI.

Normal-restart performance comparison is pending. Full-power-off persistence is
not established. Do not claim either from the same-boot benchmark, or attempt a
permanent firmware modification on the strength of this evidence. Keep secure
boot disabled as in the tested configuration; signed/trusted boot support is a
separate design rather than an installer checkbox.

## Local validation

An actual 91,648-byte MSI EFI was built and PE verified (AMD64 EFI, zero imports,
NX/ASLR). Windows PowerShell5.1 checked package inventory/local-state creation,
existing/nested-state refusal, altered/missing file refusal, duplicate inventory
refusal and automatic-policy refusal. No hardware execution was performed.
These are correctness checks, not authenticity signatures or live install proof.
