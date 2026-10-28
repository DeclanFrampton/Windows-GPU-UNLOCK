# EVGA internal boot: read-only storage inventory

[English](INTERNAL-STORAGE-INVENTORY.en.md) | [한국어](INTERNAL-STORAGE-INVENTORY.ko.md)

The validated EVGA profile currently uses a USB. The separate internal launcher belongs to a different machine and cannot be used unchanged. Before designing an EVGA internal path, this inventory identifies storage layout and possible existing dedicated EFI partitions without changing boot settings, mounting partitions, formatting or writing to disks.

From the updated branch's repository root, run:

```powershell
powershell -NoProfile -File ./research/profile/inspect-internal-storage.ps1
```

The JSON contains disk numbers, bus types, partition sizes/types, drive letters and file systems. It omits disk serial numbers and partition GUIDs; check it before sharing. Send the output or the error. A `candidate_dedicated_esp` is only a possible existing non-USB FAT32 GPT EFI partition, at least 1 GiB, with a drive letter, that Windows does not mark system or boot. It does not certify that the partition is unused, safe to write, firmware-accessible, or suitable for the EVGA profile. An EFI partition without a drive letter will not be identified as a candidate by this check. No candidate does not authorize partition changes.

Local verification: mocked system/dedicated/USB examples and read-only inventory on the research machine passed. There is no live EVGA internal boot implementation or installation in this step.
