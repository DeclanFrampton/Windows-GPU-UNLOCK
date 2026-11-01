# Pre-unlock PyTorch baseline

[한국어](CHRISTIAN-TORCH.ko.md)

The returned readiness ZIP reports Python/NVIDIA tools present, no nvcc/CUDA_PATH/cuBLAS toolkit and no torch package. The next script creates only `C:\GPU-Unlock\BenchmarkEnv-v1` and installs pinned `torch==2.14.1+cu126` from the official PyTorch CUDA 12.6 wheel index. This follows the [official wheel installation route](https://pytorch.org/get-started/previous-versions/). It does not install a system CUDA toolkit or driver or modify system Python. The download can be several GB and needs adequate disk space/network access.

Run `run-christian-torch-baseline.ps1`. It installs once, verifies the exact torch version/CUDA availability/RTX3090 name, checks 128x128 products against CPU float64, then measures four 4096x4096 GEMM modes with CUDA events. Each has ten warmup iterations and three trials of ten samples. Fixed seed, mode flags, output dtype labels, trial values and package/source provenance are retained in the ZIP under `C:\GPU-Unlock\Results`. FP16/BF16 output precision differs from the earlier cuBLAS FP32-output benchmark; compare only this protocol with itself before/after, not directly with Movian's numbers. Full-matrix finite checks and a small reference are not comprehensive numerical qualification.

This is a real GPU workload. Save work and close GPU-heavy apps first. No tuning, clocks/power-limit changes, firmware writes, EFI or reboot. If it errors/hangs, preserve partial files and report; no automatic benchmark retry or environment deletion. Send the ZIP or screenshot of errors, and report whether an unlock EFI has run before the measurement. It records current state, not proof of a locked/unlocked state.

Validation performed before handoff: PowerShell parser, embedded Python AST compilation and TFLOPS formula check. The workload has not been executed on Christian's machine or locally in the pinned environment; its first run is a live acceptance test. Any install/reference/API failure is a failed test, not measured performance.
