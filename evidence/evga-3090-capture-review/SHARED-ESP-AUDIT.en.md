# Shared ESP no-GPU handoff audit

[English](SHARED-ESP-AUDIT.en.md) | [한국어](SHARED-ESP-AUDIT.ko.md)

This new test EFI is a build-only candidate for the preferred Windows-only shared-ESP design. It requires its own loaded device to be the unique filesystem handle with the pinned Windows ESP GPT device path and refuses USB ancestry or duplicate matching handles. It then loads the existing `\EFI\Microsoft\Boot\bootmgfw.efi` from that same device, checks the loaded image device, and starts it. It does not enumerate or release GPU drivers, access GPU registers, alter PCI settings, perform an unlock, write files or firmware variables, or modify boot order. It deliberately starts Windows for that invocation; no change to the existing Limine entry is intended.

The EFI has **not** been copied to the ESP, registered as a boot entry or run on hardware. There is no reviewed deployment or recovery procedure yet. Launching it will require a separate, safely staged EFI file and a reliable way to select it without disturbing Windows or Limine. This test cannot be run merely by booting its EFI from the USB: same-volume admission intentionally refuses that. Firmware could refuse or hang during image loading or Windows handoff; an operator may need firmware boot selection or power-off, and recovery is not established. Do not deploy this build to a real ESP until its staging and recovery path are reviewed.

Build locally with the exact Windows ESP GUID (compiler paths may differ):

```powershell
./research/profile/build-shared-esp-audit.ps1 -WindowsEspGuid "c36c3e86-02aa-4f76-af1b-96e327f9d1c1"
./research/profile/test-shared-esp-audit.ps1
```

Local build is `internal-boot/boot/build/shared-esp-audit/AUDIT.EFI`, 4,608 bytes, SHA-256 `5490224b49b8a4680f82a453020da47cbfa19775f2c835e15ba1fa98b60fec5d`; other toolchains may produce a different hash. PE verification passed. Synthetic UEFI mocks exercised exact, wrong, duplicate, USB and missing partition handles, correct Windows path and handoff, wrong loaded-image device, load failure and duplicate refusal. These are host tests, not evidence of actual UEFI behavior or a successful unlock.
