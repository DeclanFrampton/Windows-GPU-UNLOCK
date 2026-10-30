# EVGA profile publication status

[한국어](PUBLICATION-STATUS.ko.md)

## Attended SULK02 evidence complete — 2026-10-30

The reviewed EVGA RTX 3090/Z790 system has completed the attended USB-free sequence: firmware launch, fresh Shift+G unlock, normal Windows return, same-session benchmark, temporary-entry cleanup and a later ordinary restart through Boot0000. The temporary option remains absent, BootNext is clear and the primary Limine/Windows entries are unchanged.

The transaction log records slot 9, successful return, released assets and two complete captures. Benchmark completion/protocol/timing checks pass and the recorded baseline context matches: FP16 +91.00%, BF16 +91.08%, TF32 +94.53%, FP32 control +0.42%. USB absence, no intervening benchmark reboot and normal Windows behavior are contributor-confirmed. [Evidence summary](sulk02-result.json) · [Benchmark review](sulk02-benchmark.json) · [Full result](SULK02-RESULT.en.md).

Cleanup deleted only Boot7E00 with saved attributes 7 and did not write BootOrder. Three generic fallback entries had disappeared beforehand; their cause remains unknown and they were not restored. The later normal-boot script made no firmware writes or GPU accesses. Successful recovery on this run does not guarantee recovery elsewhere.

## What is ready for review

The exact-machine attended implementation, evidence, benchmark comparison, one-shot receipt/reservation workflow, diagnostic/refusal handling, collection and scoped cleanup are available for maintainer review. Local mocks cover the relevant script paths and fail-closed behavior; normal-boot fixtures pass in PowerShell 7 and Windows PowerShell 5.1. These are separate from live contributor evidence.

No additional hardware test is requested for this completed SULK02 sequence. Preserve the original USB reservations, ESP receipts/logs, staged payloads and private firmware backups. Do not delete gates or rerun the consumed slot.

## Remaining software/publication work

A reusable installer/rearm interface is not complete. The current development commands are tied to reviewed slots, fixed SULK02 filenames, exact hashes and one machine. A later attempt needs a separately qualified fresh slot and build; it must not reuse SULK02. Permanent/unattended unlock, persistence across ordinary reboots, other firmware configurations and other GPUs have not been established by this evidence. Complete reusable packaging and maintainer review before calling this a general production profile. The 4070Ti research remains separate.
