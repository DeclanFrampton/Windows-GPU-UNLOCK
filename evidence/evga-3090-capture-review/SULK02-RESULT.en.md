# SULK02 result and next step

[한국어](SULK02-RESULT.ko.md)

The uploaded SULK02 log records slot 9, successful transaction return, asset release, close, Windows-ready and two complete captures. Movian reports normal Windows boot and the expected confirmation screen. [Sanitized checks and hashes](sulk02-result.json). Explicit USB-absence confirmation and the same-session benchmark are still needed before claiming the complete USB-free performance result.

Collection created the evidence ZIP, but cleanup refused with `BootOrder changed; preserve backup and stop`. Cleanup has not completed. The current order and reason for the change have not been inspected; do not assume the earlier audit's cause applies here. Preserve the private backup and temporary firmware entry. Do not retry cleanup or EFI.

**Next: benchmark. Do not run Cancel.** Cancel was an alternative for before boot, not a required step afterward. Update the branch, close GPU workloads, keep settings unchanged, and run this one command from the repository root:

```powershell
./research/profile/benchmark-shared-esp-second.ps1
```

This uses the original executable pinned to the reviewed baseline, runs the existing three-trial/four-mode benchmark and creates one ZIP including result provenance. It does not rebuild, change firmware/settings, clean up or reboot. Increased GPU load/heat or a driver/application crash is possible. On error, send the error; do not rebuild or automatically retry.

Send the ZIP path printed at the end, confirm whether USB was unplugged during the SULK02 boot, and report any reboot since that test. Do not reboot before this measurement. If a reboot already happened, report it; the current-state benchmark can still be collected but cannot be called same-session SULK02 evidence.

Local packaging checks passed with a synthetic runner: ZIP/provenance creation, changed-executable refusal and stale-result refusal. No GPU workload or native firmware API was run locally. Firmware cleanup will be handled separately after inspecting the changed state.
