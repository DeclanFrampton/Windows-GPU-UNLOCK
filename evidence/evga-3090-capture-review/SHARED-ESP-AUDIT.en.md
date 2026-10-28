# Shared ESP no-GPU handoff audit

[English](SHARED-ESP-AUDIT.en.md) | [한국어](SHARED-ESP-AUDIT.ko.md)

This new test EFI is a build-only candidate for the preferred Windows-only shared-ESP design. It requires its own loaded device to be the unique filesystem handle with the pinned Windows ESP GPT device path and refuses USB ancestry or duplicate matching handles. It then loads the existing `\EFI\Microsoft\Boot\bootmgfw.efi` from that same device, checks the loaded image device, and starts it. It does not enumerate or release GPU drivers, access GPU registers, alter PCI settings, perform an unlock, write files or firmware variables, or modify boot order. It deliberately starts Windows for that invocation; no change to the existing Limine entry is intended.

The contributor reports successful staging of the EFI on the shared ESP; it has **not** been registered as a boot entry or run on hardware. A staging-only script is now available below; a reviewed one-time selection and recovery procedure is not yet available. This test cannot be run merely by booting its EFI from the USB: same-volume admission intentionally refuses that. Firmware could refuse or hang during image loading or Windows handoff; an operator may need firmware boot selection or power-off, and recovery is not established. **Do not boot or register the file until the selection and recovery path has been reviewed.**

Build locally with the exact Windows ESP GUID (compiler paths may differ):

```powershell
./research/profile/build-shared-esp-audit.ps1 -WindowsEspGuid "c36c3e86-02aa-4f76-af1b-96e327f9d1c1"
./research/profile/test-shared-esp-audit.ps1
```

Local build is `internal-boot/boot/build/shared-esp-audit/AUDIT.EFI`, 4,608 bytes, SHA-256 `5490224b49b8a4680f82a453020da47cbfa19775f2c835e15ba1fa98b60fec5d`; other toolchains may produce a different hash. PE verification passed. Synthetic UEFI mocks exercised exact, wrong, duplicate, USB and missing partition handles, correct Windows path and handoff, wrong loaded-image device, load failure and duplicate refusal. These are host tests, not evidence of actual UEFI behavior or a successful unlock.

## Optional staging-only test

The staging script validates the locally built source/manifest and exact system-partition GUID, requires a FAT32 volume, checks all ancestor components for reparse points, compares the previously reported Windows and Limine EFI hashes, and creates the new `EFI/EVGA-SHARED-AUDIT.EFI` with create-new semantics. It verifies the new hash and rechecks both boot-file hashes. It never intentionally overwrites a file, creates a boot entry, changes boot order or reboots. `-WhatIf` skips all copying; it does not execute the boot-file hash and target checks inside the copy operation. If a partial copy or post-copy verification fails, preserve it and report the error; there is no automatic deletion.

**Risk:** this writes a new file to the active, shared Windows/CachyOS ESP. Filesystem errors, interruption or unexpected external changes could affect boot or data; preservation and recovery are not guaranteed. Proceed only with backups and if the machine's owner accepts that risk. The checks do not eliminate time-of-check/time-of-use races or prove firmware behavior. The full stage script passed fixture tests with mocked storage and boot-file hashes; the contributor subsequently reported a successful stage on this ESP, including both boot-file hash checks.

After the build above, from an administrator PowerShell, first inspect the plan and then, only if acceptable, stage:

```powershell
./research/profile/stage-shared-esp-audit.ps1 -WindowsEspGuid "c36c3e86-02aa-4f76-af1b-96e327f9d1c1" -WhatIf
./research/profile/stage-shared-esp-audit.ps1 -WindowsEspGuid "c36c3e86-02aa-4f76-af1b-96e327f9d1c1"
```

Send the output or error. Do not delete files or repeat a refused staging attempt. The existing Windows/Limine hashes are exact observed pins; a legitimate update to either file will refuse staging and must be reviewed.

## Contributor staging result

On 2026-10-28, the contributor reported a 4,096-byte build with SHA-256 `cfd24d9a1bdcf9fba0c1a7cd0bd314bf494d91c00bb39e3e30d2da87bcd4bbe5`, ten passing host mocks, and successful create-new staging with both existing boot-file hash checks. This is reported script output, not an independently inspected ESP or a boot test. No boot entry was changed.

## USB launcher test

A separate USB launcher locates the pinned ESP and loads the staged audit from that ESP without changing firmware entries or boot order. The audit then attempts a direct Windows handoff. This tests same-ESP loading but does not provide an installed or automatic unlock, access the GPU, or establish that either handoff works on firmware. The launcher checks the loaded image device; it does not hash the audit at runtime. The staging script checks the previously reported audit hash from Windows before and after copying the launcher, but cannot prevent later changes.

Use a separate FAT32 USB with no `EFI` directory; the script refuses an existing directory and never formats the drive. It verifies the disk reports USB and is not a system/boot partition, but unexpected storage errors and interruption can still cause data loss. Back up the USB. Firmware may hang or refuse an unsigned EFI; if it does not reach Windows, power off, remove the USB and select the normal Limine or Windows boot entry. Recovery is not guaranteed. The test makes no persistent firmware configuration changes by design, but does not prove boot recovery.

Build and run the host tests, then stage to the chosen USB using `stage-shared-esp-launcher.ps1 -Drive <letter> -WindowsEspGuid <guid>`; `-WhatIf` skips the copy. No existing EFI or capture USB is overwritten. Preserve any partial files after failure. The launcher and staging have passed simulated tests only; a real boot remains pending.
