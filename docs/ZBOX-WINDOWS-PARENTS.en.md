# ZBOX existing Windows PCI associations (#167)

```powershell
powershell -NoProfile -File .\tools\test-pci-parents.ps1 -Case 167
```

Uses the shared Windows-only parent reader with exact2504/263019da and
9bc8/b44019da data, returning the NVIDIA chain first, Intel chain second.
Mock tests verify RDP cannot substitute for the Intel PCI adapter; no RDP
parent lookup or ROOT/SWD exception is granted. This is not preboot topology,
a physical monitor/cable verification or an available recovery-path proof.
The EFI preparer's unknown-identity refusal remains unchanged. The same GPU
identity in another board profile does not transfer that board's qualification.

Expect observed and two bounded chains, or an explicit unavailable/target-not-unique.
Return only reviewed pci-parents.json from the printed Documents folder.
No Python, administrator rights, firmware, PCI config/MMIO, driver changes,
settings changes, cable relocation, EFI or reboot. RDP may remain as it is.
If blocked/failing, stop and return a short sanitized error; do not remove
virtual adapters or reconnect the monitor to make the test pass.
