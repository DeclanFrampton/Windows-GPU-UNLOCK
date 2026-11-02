# Issue17 Windows target separation

The existing PCI-parent reader now accepts exact case17 data. It selects
2204/40411458 and1e04/12fa10de exactly once each; it never traverses the
non-target2c02/41781458 device. Missing or duplicate targets stop selection.
Mock tests cover both targets, excluded5080, duplicates and missing targets.

```powershell
powershell -NoProfile -File .\tools\test-pci-parents.ps1 -Case 17
```

Expect ReadStatus observed and two bounded Windows parent chains, or an
explicit unavailable/target-not-unique result. Return only reviewed
pci-parents.json from the printed Documents folder. Raw device instance paths
are omitted. No admin, Python, driver change, PCI config/MMIO, EFI or reboot.
Keep all cards, cables and settings unchanged. If blocked/failing, stop and
send a short sanitized error; do not remove a card to make this test pass.

This inspects Windows associations toward a multi-target isolation review.
It does not prove physical slots, link width, firmware ownership, independent
release or unlock. TU1021e04 is outside current generic probe admission;
vendor helper names do not grant family support. No GPU is admitted by this test.
