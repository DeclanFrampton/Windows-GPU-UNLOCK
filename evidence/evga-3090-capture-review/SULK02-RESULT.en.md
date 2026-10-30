# SULK02 result and next step

[한국어](SULK02-RESULT.ko.md)

The uploaded SULK02 log records slot 9, successful transaction return, asset release, close, Windows-ready and two complete captures. Movian reports normal Windows boot and the expected confirmation screen, and explicitly confirms USB was absent, Shift+G was used and no reboot occurred before the benchmark. [Sanitized checks and hashes](sulk02-result.json).

The completed benchmark passes the offline completion, protocol, timing and identity checks. Its recorded artifact/runtime/settings context equals the baseline. [Sanitized benchmark review](sulk02-benchmark.json).

| Mode | Baseline TFLOPS | SULK02 TFLOPS | Change |
| --- | ---: | ---: | ---: |
| FP32 pedantic | 26.379272 | 26.489006 | +0.42% |
| FP16 tensor | 64.527754 | 123.248599 | +91.00% |
| BF16 tensor | 64.558792 | 123.361880 | +91.08% |
| TF32 tensor | 32.982266 | 64.159053 | +94.53% |

This supports attended USB-free unlock on the reviewed machine. Session timing and USB absence are operator-reported, not independent attestation. Manual tuning was not freshly reconfirmed; the recorded settings match. These GEMM results do not establish all-workload gains, complete numerical correctness or long-term stability. The reusable profile is not finished while cleanup remains blocked.

Collection created the evidence ZIP, but cleanup refused with `BootOrder changed; preserve backup and stop`. Cleanup has not completed. The subsequent comparison identifies the exact contraction: the four Limine/Windows/USB entries match, while generic fallback entries 000E/000F/0010 are absent. The cause is unknown. Preserve the private backup and temporary firmware entry. Do not retry cleanup or EFI.

**Next: [finish exact-owned cleanup](SULK02-CLEANUP.en.md).** Update the branch and run this one command in administrator PowerShell from the repository root:

```powershell
./research/profile/cleanup-shared-esp-second.ps1
```

Send the JSON or error. This writes a new local snapshot and deletes only the reviewed Boot7E00 entry. It preserves the current order and all evidence; no reboot or GPU work. Read the linked procedure for the firmware-write risk, stop conditions and recovery limits. The actual cleanup result remains pending.

Local benchmark packaging checks previously passed with a synthetic runner. The performance data above came from the contributor, not local hardware execution. Firmware cleanup will be handled separately after inspecting the changed state.
