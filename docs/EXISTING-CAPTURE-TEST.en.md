# Check an existing probe refusal

**English** | [한국어](EXISTING-CAPTURE-TEST.ko.md)

This is an offline reporting test for #114 and #160. Use the DIAG files you
already have. No new EFI boot, GPU access, administrator rights or settings
change is required. Source captures are read without modification.

Open PowerShell in the extracted test source folder and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-existing-captures.ps1
```

When prompted, enter the folder containing your existing `DIAG00.TXT` and
`DIAG01.TXT`. If script policy blocks execution, report it; do not change policy.
If `python.exe` resolves to a stub/alias, add `-Python "C:\path\to\python.exe"`
using the same known-good Python 3 executable you already use. The launcher
checks that interpreter before running the checker; no PATH edits are needed.

For the exact refusal markers reported in these issues, expect
`probe_envelope_refused` instead of `invalid_graph`. The overall status stays
`invalid_data`, with `write_eligible: false` and `hardware_tested: false`.
This explains a recorded refusal; it does not validate the rest of the log or
approve a profile. Other or conflicting failures may still show `invalid_graph`.
For #170's combined envelope refusal and unavailable GOP information, expect
`multiple_capture_failures` if the log contains exactly those two failure markers
and the incomplete/failed footer. This does not establish either root cause.

Review and attach **report.json and result.json** from the new
`Documents\GPU-Unlock-Capture-Check-...` folder. Do not upload raw driver/PROM
images or a full system report. If the script fails, send the files that exist
or the short error with personal paths removed, then stop. Do not boot EFI again.

For #104, a single existing DIAG00.TXT with the reported envelope refusal is
sufficient for this classification test. PROM and IMG files are not required.
Do not collect a second capture to clear the capture-count warning. Automatic
Windows/display return is an owner observation, not profile or unlock proof.
Keep the currently enabled Secure Boot setting unchanged.

For #75, current generation supports aggregate console graphs; the old
two-GOP refusal is not the current blanket rule. A synthetic root-UID1
aggregate regression accepts the reported SS0/SS1 pairs without changing
structural pins, while route drift still fails. This is source behavior,
not proof the actual captures pass or the register differences are harmless.
Use the already saved captures/images with this same offline checker. No new
cold-monitor capture, BIOS/driver change, profile borrowing or hardware run.

For #52, the non-aggregate generator now distinguishes a missing ConOut record,
EFI_NOT_FOUND/no path, ambiguous records and a present mismatching route.
Recognized aggregate graphs use the existing full live ownership contract and
do not synthesize NVRAM output variables. Missing NVRAM alone is not admission;
a wrong combo identity still refuses. Recheck existing captures only.

For #20, the published sanitized capture was read as data: one physical GOP,
2206/161210de, GA102/10240MiB. A regression preserves outside_scope/gpu_scope
without borrowing3090 admission; one saved capture also retains capture_count.
The diagnostic compile flag GU_CONSOLE_AGGREGATE does not establish an observed
aggregate graph. Do not collect another boot just to clear count; existing
complete evidence is the next source-review input, not an armed profile.
