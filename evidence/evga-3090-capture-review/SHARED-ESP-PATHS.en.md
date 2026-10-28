# Shared ESP: read-only path check

[English](SHARED-ESP-PATHS.en.md) | [한국어](SHARED-ESP-PATHS.ko.md)

Before any shared-ESP implementation, inspect only the two reported boot files and two possible project directories on the existing system volume. The script asks Windows for the system volume's existing path, verifies it is FAT32, and checks file metadata/hashes and directory existence. It does not assign a drive letter, mount a partition, enumerate unrelated files, write to the ESP, change boot configuration or reboot.

After updating the branch, run from the repository root in PowerShell:

```powershell
powershell -NoProfile -File ./research/profile/inspect-shared-esp-files.ps1
```

Access may require an administrator PowerShell. Stop and send the error if the volume path is inaccessible. Review the JSON before sharing: it contains fixed EFI paths, file sizes and hashes. No volume GUID or file contents are printed. Missing paths or existing project directories are observations, not permission to overwrite them. The script refuses unexpected object types and reparse points at the final path; it does not validate every ancestor or prove future writes or firmware boot are safe.

Fixture tests covered present and missing files/directories and hashes without touching an ESP. The research machine's system volume was not reported as FAT32, so its live run refused as designed; actual access on Movian's machine remains untested.
