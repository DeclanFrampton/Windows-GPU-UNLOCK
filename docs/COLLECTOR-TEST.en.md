# Windows collector test

**English** | [한국어](COLLECTOR-TEST.ko.md)

This tests the Unicode reader-thread failure reported in #27, #110, #127 and
#130. It runs synthetic checks, then the Windows inventory collector. It needs
Python, Windows and a normal PowerShell window. No administrator access, reboot,
USB, EFI or firmware-setting change is required.

From the downloaded source folder, run this **one command**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-collector.ps1
```

The execution-policy option applies to this PowerShell process; it does not save
a machine policy change. If an organizational policy blocks it, stop and report
the message rather than changing policy.

Expected: `Result: PASS`. The script prints the new
`Documents\GPU-Unlock-Collector-Test-<id>` folder. In `inventory.json`, expect
`collection_complete: true`, `assessment.status: not-assessed` and
`can_unlock: false`. No `UnicodeDecodeError` should appear. This does not test
GPU unlock or establish hardware support.

**Send back:** review and attach `result.json` and `inventory.json` from that
folder to your existing issue. State whether a Unicode error appeared. Do not
attach a full system report, firmware images or screenshots containing personal
paths. The collector selects model/version fields and removes device-instance
suffixes; review the files before posting.

If the result is `PARTIAL` or `FAILED`, send `result.json` and `inventory.json`
if present. If no folder was created, paste only the short error message after
removing personal paths. Stop there; no rerun or setting change is needed.
