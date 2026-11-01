# Christian Windows baseline test

## Returned result — 2026-11-01

The contributor ZIP reports ASUS PRIME H510M-K R2.0, AMI BIOS 0802, RTX3090 subsystem 38811462, driver 596.49 and 24576 MiB. The NVIDIA query succeeded. Both diagnostic hashes match the previously reviewed captures. Reported telemetry includes P0, 350 W limit and maximum SM/memory clocks 2130/9751 MHz; these are observations, not recommended settings or benchmark evidence. No GPU workload or unlock was run.

Next: `test-christian-benchmark-readiness.ps1`, producing a ZIP under `C:\GPU-Unlock\Results`. It discovers existing nvcc/Python/NVIDIA commands, CUDA header/library presence and whether Python can find torch, without importing torch or launching GPU work. Missing tools are a valid result, not a request to install them. This selects a practical pre-unlock benchmark route while driver-release research continues. It does not qualify the Stop path. Mocked missing/present tool tests pass in PowerShell 7/5.1.

[한국어](CHRISTIAN-BASELINE.ko.md)

Run `research/profile/collect-christian-baseline.ps1`. Defaults: saved captures `C:\GPU-Unlock\Captures`; unique output directory and ZIP under `C:\GPU-Unlock\Results`. Send the printed ZIP. No administrator access or reboot is required.

The script reads Windows build/boot time, board product, BIOS version, GPU driver/PCI identity and a bounded NVIDIA telemetry query. It hashes the two saved diagnostics without copying their raw contents. Serial numbers, full PNP instance identifiers and raw firmware dumps are excluded. NVIDIA query failure is recorded rather than converted to successful telemetry. No GPU workload, benchmark, tuning, firmware write, EFI execution or unlock occurs. This is a current-configuration baseline, not a performance baseline or Stop-path qualification.

Mock tests pass in PowerShell 7 and Windows PowerShell 5.1: ZIP creation, allowed NVIDIA query arguments, serial/instance exclusion, capture hashes and wrong-GPU refusal before output. Live telemetry is not established by these mocks. Preserve captures and current BIOS settings; on error send the error instead of repeating an EFI.
