# Measurements on the actual RTX 4070 Ti

Date: 2026-10-25. The owner explicitly authorized ordinary GPU execution and
freeing competing GPU applications. This phase uses the stock CUDA driver for
bounded user-space compute, without raw PCI/MMIO, firmware, driver installation,
reset or clock/power configuration changes. Nothing is pushed remotely.

## Hardware-derived observations

| Observed field | Value |
|---|---|
| GPU / subsystem | RTX 4070 Ti, `10de:2782` / `1462:5132` |
| NVIDIA Windows driver / VBIOS | `610.88` / `95.04.31.00.f0` |
| CUDA compute capability | 8.9 |
| CUDA driver API version | 13030 (driver API version, not an installed toolkit/cuBLAS version) |
| Windows CUDA PCI address | **`0000:0B:00.0`** |

The last row is new measured portability evidence: this Windows address differs
from the external reference sampler's hardcoded `0000:01:00.0`. Do not change
the guard just to match it. Firmware-time enumeration/resource layout still
requires separate evidence; Windows BDF alone does not prove a preboot rejection.

Trackmania was closed normally using its window-close request, under the owner's
authorization. No force termination or system/display-process termination was
used. GPU memory dropped from approximately 6.8 GiB to 5.5 GiB in subsequent
telemetry, but other activity remained. No raw process inventory is published.

## Stock CUDA correctness smoke: passed on hardware

[gpu_smoke.py](gpu_smoke.py) uses [cuda_driver.py](cuda_driver.py) to load PTX
through the installed `System32/nvcuda.dll`. No Python GPU package or toolkit was
installed. It creates its own logical CUDA context and 256 KiB device buffer.
Ten launches each fill 65,536 uint32 values with `3*index + bias`; bias changes
from 7 through 16 so later successful checks cannot rely on a prior launch's
identical output. Every element is copied back and checked after each launch:
**655,360 exact values verified**. All own resources were released successfully.

[gpu-smoke-result.json](gpu-smoke-result.json) contains the measured device/API
identity, telemetry, output hash and source hashes. Host elapsed time, including
JIT/context/validation/cleanup, was about 0.35 s; this is not a compute-throughput
measurement. The allocation figure excludes normal driver/context overhead.

Before/after telemetry both reported 34 C, 20.06 W and a configured 285 W power
limit. These are coarse point samples, not peak measurements. Utilization was
49% and memory use about 5.5 GiB, so the system was not an idle benchmark host.
`cuMemGetInfo` values are retained as CUDA/WDDM allocation information; do not
subtract them from NVML memory-use values as if the APIs measured identical
physical residency.

Reproduce the same bounded test:

```powershell
python research/ada-4070ti/gpu_smoke.py
```

This proves successful ordinary CUDA execution and exact output for this test
on this GPU/driver. It does not prove any selector state, Tensor Core throughput,
unlockability, firmware compatibility or performance uplift. The per-launch
pattern varies to distinguish fresh results from stale output.

## Stock FP16/BF16 Tensor Core probe: first run

[gpu_tensor_probe.py](gpu_tensor_probe.py) then executed native `sm_89` PTX
`mma.sync.aligned.m16n8k16` with FP16 or BF16 inputs and FP32 accumulation.
It first checks one warp/eight iterations, then a 512-iteration warmup. Timed
launches use 120 blocks of 256 threads, four PTX accumulator chains and 4096
iterations per chain. Inputs are runtime-supplied packed ones. Chain-specific
seeds make the recurrences distinct, and seeds change for each timed launch.
All 491,520 FP32 output values are copied back and checked after every timed
launch. Expected values remain exactly representable in FP32.

| First process, seven samples/mode | Median time | Nominal TFLOP/s |
|---|---:|---:|
| FP16 inputs / FP32 accumulation | 0.923264 ms | 69.7791 |
| BF16 inputs / FP32 accumulation | 0.897152 ms | 71.8100 |

[gpu-tensor-result-1.json](gpu-tensor-result-1.json) records raw event timings,
telemetry, output/PTX/source hashes and successful cleanup. The output allocation
is 1,966,080 bytes. Timed nominal work is `960 warps * 4 chains * 4096 iterations
* (2*16*8*16)` = 64,424,509,440 FLOPs per launch. Event timing excludes CPU output
validation and JIT. Nominal TFLOP/s is that operation count divided by event time.

Point telemetry after each mode showed 34 C, 2745 MHz SM clock and P2. Power
samples were 28.14 W and 41.79 W, not peak power. The configured power limit
remained 285 W. Background activity and memory usage changed during the session;
samples contain visible timing outliers. No processes beyond the normally closed
game were stopped to obtain these results.

Limits: this is short register-resident work, not a matrix multiplication of
application-sized arrays, cuBLAS, sustained peak throughput or a stability soak.
No disassembly of the driver's generated machine code was obtained, so executed
instruction count is not independently certified. The 100 ms timing rejection
is checked after execution, not an execution watchdog. Neither the measured
rates nor FP16/BF16 similarity identify speed-selector state or show an unlock
percentage. There is no unlocked run of this machine for comparison.

Reproduce:

```powershell
python research/ada-4070ti/gpu_tensor_probe.py
```

Instruction semantics: [NVIDIA PTX ISA, warp-level MMA](https://docs.nvidia.com/cuda/parallel-thread-execution/index.html#warp-level-matrix-instructions-mma).
CUDA uses an ordinary private logical context; destroying that context is not a
physical GPU reset.
