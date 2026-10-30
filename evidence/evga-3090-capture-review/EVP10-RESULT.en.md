# EVP10 acceptance result — 2026-10-30

[한국어](EVP10-RESULT.ko.md)

The contributor reported live guards, Shift+G, a hang and forced power-cycle recovery. USB was absent during the attempt. Collection reports missing transaction-return evidence and refuses cleanup for an unreviewed additional boot entry. This reusable packaging is not yet hardware-qualified; earlier SULK02 success does not establish success here.

The supplied photograph ends at the fresh-input prompt. It cannot identify the last completed transaction stage. The reported built EFI hash is `19eaa39d564dbb2a341bbb57cfd3c1b0877f00fe7d13f5183ff93056331f8ef8`, different from the local package; toolchain/source provenance requires inspection before attributing the failure.

Preserve the failed slot and state. Do not rearm or relax cleanup guards. After Collect, run `./research/profile/inspect-evga-package-failure.ps1` and send its ZIP. This copies the existing results ZIP and reads boot-entry names, descriptions and hashes for comparison. It makes no firmware writes and does not access the GPU. Private raw firmware backups are excluded. The controller remains blocked until the log and boot-entry difference are reviewed.

The inspection passed a synthetic incomplete-transaction/additional-boot-entry case with fake Native storage and zero firmware writes. This is a diagnostic test, not a new EFI retry.

For offline triage, run `python -I research/profile/review-evga-failure-zip.py "path-to-inspection.zip"`. It reads the outer/nested ZIP without extraction, reports the last 35 log lines, receipt prefix, capture count and boot-entry changes, and never authorizes a retry. It rejects ambiguous duplicate records and bounded-size violations. Three synthetic tests cover partial-run reporting, duplicate rejection and expanded-size rejection. The generated ZIP must be attached for review; console output containing its local path does not transfer its contents.
