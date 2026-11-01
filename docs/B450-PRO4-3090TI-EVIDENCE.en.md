# ASRock B450 Pro4 P4.20 / RTX3090Ti reported-success intake (issue190)

Owner reports Ryzen2700/noiGPU,3090Ti220310de/161810de,bus0x0A,24564MiB;
physical brand unknown, no reported flash/crossflash, Parsec software display present.
Two supervised local-profile USB unlock boots reportedly returned directly to Windows
with display working. Reported local profile LOCAL-220310de-161810de-6263592b and22
host jobs; only build/PROM hash prefixes and release0.3.1 snapshot label supplied.
These are reports, not independently verified transaction/cleanup/provenance evidence.
Do not send the owner back through capture, unlock, settings or performance runs.

The shared existing-profile audit has a new synthetic3090Ti/0x5ff4-memory case,
using the actual trusted header parser; it does not run old-checkout code. To review
existing files only, use a fresh pinned folder outside the tested checkout:
```powershell
powershell -NoProfile -File .\research\profile\test-profile-review.ps1
```
Enter the original tested checkout. Expected profile-review.json: source/header/
fixture/host-receipt bindings and numeric pins, with all hardware/admission flags false.
Return that reviewed JSON; additionally existing profile.json, Format2 test receipt and
successful transaction reports may be shared only if already available and sanitized.
No raw PROM/IMG, serials, home paths or partition identifiers. If missing/old format/error,
stop and report unknown/unavailable or short sanitized error; no regeneration or rerun.

Benchmark distinction:140 versus87.5BF16 is60% against a published reference, not an
own-machine matched control.131.7 versus87.5FP16 is50.51% on that same reference basis.
Reported same-protocol decode50.88vs49.08 is3.67%; it is not a GPU tensor/unlock causal
proof. Keep protocol/power/clock/workload/raw-timing limitations explicit. No further
benchmark requested merely to improve this report.

No source/profile admission is changed. Next step is existing evidence/source review,
not inventory. Source audit passing would still be owner-run; local document relationships
and actual physical results must remain separate.
