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

## Prepared attempt identity

Local preparation also writes Attempts/attempt-0001.json with a random immutable
attempt ID, package/EFI/asset-manifest hashes and the reviewed DIAG14 evidence
hash. File creation uses CreateNew, exclusive access and a durable Flush(true),
then reads back its identity/binding. It is PreparedNotArmed and explicitly not
execution authorization. An existing attempt directory entry blocks another
plan, including pending, failed or ambiguous state. Records are never overwritten.
This is the host preparation foundation; EFI STARTED/FINISHED receipt production
and successful-result-driven creation of attempt2 remain to be implemented.
No current helper can turn this plan into an arm marker.

Tests additionally verify correct binding, pending-plan refusal and preservation
of the original file hash after an attempted overwrite. The one-script contributor
preparation is pinned to the preceding preparation revision; do not silently
upgrade or replace an existing contributor state to add this newer journal.

## Exact-attempt EFI receipt implementation

The receipt variant of build-probe.ps1 takes an explicit 32-hex MsiAttemptId and
embeds distinct MA<ID>.ARMED/STARTED/FINISHED paths. It verifies the exact ARM ID,
refuses any existing STARTED/FINISHED receipt, writes/flushes/closes and reads back
STARTED before consuming the arm and before driver release. A failed write,
flush, readback, close or arm deletion holds; any partial STARTED file blocks
repeat execution. FINISHED is written/read back only after successful transaction,
resource cleanup and diagnostic logging, before attempting Windows handoff.
FINISHED therefore does not independently prove Windows started.

The legacy one-shot build remains separate and unchanged when MsiAttemptId is
absent. Generated configuration is private/ignored; its hash is in the build
manifest. The generic capture object does not receive the attempt/write flags.
The existing-state report from Christian (1566601541337481226) verified the old
preparation complete, not installed or armed, with no host attempt plan present.
It is preserved rather than silently migrated.

A 93,696-byte receipt EFI built and passed PE verification. CPU tests passed
23 transaction-wrapper/repeat cases,17 graph cases,13 receipt-begin cases and6
receipt-finish fault cases, including pending/finished refusal, exact arm mismatch,
short writes, flush/readback/close/delete failures. No hardware execution occurred.
The next live boundary is one separately identified attended rearm; no automatic
retry, unrestricted rearm loop or unattended deployment is implemented.

## First receipt-bound attended rearm handoff

The existing preparation was verified complete by Christian's report
christian-preparation-report-ab9eaf952bec4ec5a4864c675b5b1a87.zip
(message1566601541337481226), package manifest SHA256
6395d1d06a4e7485c286eb253aec7b652692795d0a4fcb03270940c9889037a2.

run-christian-rearm.ps1 stages one new attempt only. It requires the reviewed
successful DIAG14 and prepared-package hashes, verifies all local/USB payloads,
backs up the original EFI/captures, generates a fresh compiled attempt ID and
installs the matching receipt-enabled EFI. A durable exclusive host preparation
claim prevents concurrent/repeated staging. The old MSI-UNLOCK.STAGED and all
old evidence remain. Only the new MA<ID>.ARMED is created, last, with flush and
readback. The old MSI-UNLOCK.ARMED is never recreated. No boot, retry, firmware
variable or BootOrder write is performed by the script. This is one bounded rearm
validation, not an unrestricted reusable or unattended installer.

Collect checks the matching STARTED/FINISHED bodies and exactly one matching
DIAG log with transaction/cleanup completion. It asks automatic Windows return
and makes christian-rearm-result ZIP without ASSETS or a new benchmark workload.
A missing/partial receipt is not success. Do not retry/rearm after an error/hang;
preserve receipts and report. After10 minutes without Windows, manual power-off,
USB removal and normal Windows Boot Manager are the recovery instructions, not
a guarantee of recovery. New filesystem receipt failure can hold boot; the same
GPU writes/DMA/firmware execution/FLR risks apply as the first transaction.

Actual pinned archive download/build/PE and mocked FAT32 USB stage/readback passed
with a 93,696-byte EFI. Tests checked exact arm content, preservation of old state,
partial evidence rejection, synthetic completed-receipt collection and repeated
stage refusal. The default read-only probe also rebuilt/PE-verified. Receipt
fault tests and simulated staging are local proof only; the new live rearm is
not yet demonstrated. No raw captures or NVIDIA payloads were committed.

## 2026-11-02 boot-history review and rearm hold

Christian's v2 report (1566610577361600632) confirms the failed display-return
Windows session started00:09:47.500Z, then stopped00:12:21.752Z; recovery Windows
started00:12:44.500Z. Kernel-General stop and EventLog shutdown records exist.
Both sessions and the successful first23:26:59 session record BootType0 and the
same NOEXECUTE/FVEBOOT/NOVGA option strings. These records do not identify a new
boot-mode difference or justify changing BCD/Fast Startup settings. The recovery
query cannot expose the earlier GPU/display state; no causal firmware correction
has been established. No new armed attempt is justified by this evidence.

The current run-christian-rearm.ps1 now rejects Stage before any storage access;
Collect stays available. msi-rearm-policy.ps1 separates matching EFI receipts,
automatic Windows return and normal display return. Manual power-off, late/unknown
picture, missing receipts or mismatched identity block qualification. A clean
review result still never authorizes execution. WindowsPowerShell5.1 tests passed
all these refusal cases and the staging hold; replay of the actual EFI/display
reports is blocked specifically for manual display recovery. This does not revoke
old pinned downloads; preserve the existing markers and do not reuse them.

The exact MSI first attended unlock/same-boot performance evidence remains valid.
Receipt rearm EFI completion remains valid. Reliable display return, reusable
rearm, unattended deployment and permanence are not established. Maintainer review
of the post-FLR/display handoff needs a justified change or additional diagnostic
capability before another informed hardware attempt. Further generic collectors
or repeated unchanged EFI runs are not a substitute for that missing diagnosis.
