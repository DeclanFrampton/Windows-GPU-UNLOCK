# EVGA post-shutdown benchmark (preliminary)

[English](COLD-BOOT-RESULT.en.md) | [한국어](COLD-BOOT-RESULT.ko.md)

Movian reported shutting down and booting Windows normally without the unlock EFI. His posted three-trial medians were FP32 26.411228, FP16 tensor 64.762241, BF16 tensor 64.683243 and TF32 tensor 32.965178 TFLOPS. These are near the original pre-attempt baseline and far below the post-EVGA19 tensor results, strongly suggesting the performance effect did not persist through that shutdown on this machine.

The console output and reported sequence are preliminary: the full result folder has been requested but has not yet been inspected, and the shutdown method was not independently verified. Warm restart, sleep and hibernation remain untested. The next attended EFI attempt and matching benchmark are described in [the repeat test](NEXT-REPEAT-UNLOCK.en.md).
