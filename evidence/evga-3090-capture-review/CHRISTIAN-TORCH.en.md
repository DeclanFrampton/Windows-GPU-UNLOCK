# Pre-unlock PyTorch baseline

## Returned baseline and large-matrix check

The contributor completed the pinned runner. Source hash matches its receipt; trial values are finite and medians recompute correctly: FP32 23.489277, FP16-output 67.294447, BF16-output 68.373777, TF32 33.846756 TFLOPS. [Sanitized review](christian-torch-baseline.json). This establishes current performance only; explicit prior-unlock-history confirmation is still requested.

Next `check-christian-large-gemm.ps1` reuses the existing environment without installing anything. It checks eight fixed entries in each 4096x4096 output against CPU float64 dot products of the quantized input rows/columns, plus output finiteness. This closes part of the gap between the initial 128x128 reference and timed matrix size; 32 sampled values are not exhaustive validation. It saves the runner and checks JSON/ZIP under the fixed Results directory. No timing comparison, tuning, firmware writes or reboot. Send the ZIP even if passed=false. On runtime errors preserve files and send the error, without automatic retries. PowerShell syntax and embedded Python compilation pass; live GPU correctness results are pending.

[한국어](CHRISTIAN-TORCH.ko.md)

The returned readiness ZIP reports Python/NVIDIA tools present, no nvcc/CUDA_PATH/cuBLAS toolkit and no torch package. The next script creates only `C:\GPU-Unlock\BenchmarkEnv-v1` and installs pinned `torch==2.14.1+cu126` from the official PyTorch CUDA 12.6 wheel index. This follows the [official wheel installation route](https://pytorch.org/get-started/previous-versions/). It does not install a system CUDA toolkit or driver or modify system Python. The download can be several GB and needs adequate disk space/network access.

Run `run-christian-torch-baseline.ps1`. It installs once, verifies the exact torch version/CUDA availability/RTX3090 name, checks 128x128 products against CPU float64, then measures four 4096x4096 GEMM modes with CUDA events. Each has ten warmup iterations and three trials of ten samples. Fixed seed, mode flags, output dtype labels, trial values and package/source provenance are retained in the ZIP under `C:\GPU-Unlock\Results`. FP16/BF16 output precision differs from the earlier cuBLAS FP32-output benchmark; compare only this protocol with itself before/after, not directly with Movian's numbers. Full-matrix finite checks and a small reference are not comprehensive numerical qualification.

This is a real GPU workload. Save work and close GPU-heavy apps first. No tuning, clocks/power-limit changes, firmware writes, EFI or reboot. If it errors/hangs, preserve partial files and report; no automatic benchmark retry or environment deletion. Send the ZIP or screenshot of errors, and report whether an unlock EFI has run before the measurement. It records current state, not proof of a locked/unlocked state.

Validation performed before handoff: PowerShell parser, embedded Python AST compilation and TFLOPS formula check. The workload has not been executed on Christian's machine or locally in the pinned environment; its first run is a live acceptance test. Any install/reference/API failure is a failed test, not measured performance.
