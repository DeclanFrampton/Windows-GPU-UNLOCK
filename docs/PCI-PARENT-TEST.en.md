# Windows PCI parent associations (#108)

Run from extracted pinned source in normal Windows PowerShell:

```powershell
powershell -NoProfile -File .\tools\test-pci-parents.ps1
```

Reads present display inventory and DEVPKEY_Device_Parent only for the unique
2208/40811458 target and up to 16 ancestors. Exports numeric PCI IDs/subsystems
and hop order; raw instance paths, serials, names and error text are omitted.
This does not prove OCuLink connector identity, firmware topology, ownership,
release or unlock. Secure Boot stays enabled. No Python, admin requirement,
firmware dump, PCI config/MMIO access, driver change, EFI staging or reboot.

Return only reviewed pci-parents.json from the printed Documents folder.
Expect observed with one chain if the target is uniquely present; unknown,
unavailable, target-not-unique, cycle or hop-limit are acceptable stopping
results. Do not move/reconnect hardware, elevate, change settings or retry EFI
to clear a result. If script policy blocks it, return the short sanitized error.

Developer mock regression: add -SelfTest. Local Windows export validation
does not establish this contributor's topology or hardware compatibility.
