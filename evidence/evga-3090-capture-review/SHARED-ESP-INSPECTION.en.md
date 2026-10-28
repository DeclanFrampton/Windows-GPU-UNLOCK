# Shared ESP: read-only boot inspection

[English](SHARED-ESP-INSPECTION.en.md) | [한국어](SHARED-ESP-INSPECTION.ko.md)

Movian prefers a separate entry on his existing Windows/CachyOS ESP. The current EVGA EFI accepts USB media and directly starts the pinned Windows Boot Manager after the transaction. It therefore bypasses Linux selection for that invocation; that does not by itself delete or change the existing dual-boot configuration. Existing internal code rejects using the same partition for the unlock image and Windows. A shared-ESP EVGA profile is not implemented or tested.

The next inspection queries the existing system volume's filesystem and capacity/free bytes, and enumerates firmware boot entries via `bcdedit /enum firmware`. It does not mount the ESP, list or write its files, modify firmware entries, change boot order, or reboot. It may need an administrator PowerShell to read firmware entries; if refused, send the error. Stop on any error.

After updating the branch, run from the repository root:

```powershell
powershell -NoProfile -File ./research/profile/inspect-shared-esp.ps1
```

Review the output before sharing: firmware entries can contain identifiers, device details and boot paths. Redact anything private, retaining entry descriptions and EFI paths if comfortable. These are leads to the current boot topology; firmware enumeration does not prove loader behavior, safe shared writes or recovery. Do not resize partitions or install a launcher based on this output.

Host mocks passed success and enumeration-failure scenarios. A read-only attempt on the research machine did not succeed, so the command has not been verified on Movian's machine.
