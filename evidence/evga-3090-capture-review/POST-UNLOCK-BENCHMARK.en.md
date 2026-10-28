# EVGA post-attempt benchmark

[English](POST-UNLOCK-BENCHMARK.en.md) | [한국어](POST-UNLOCK-BENCHMARK.ko.md)

After the [successful EVGA19 transaction](EVGA19-RESULT.en.md) and reported automatic Windows boot, Movian ran the same three-trial GEMM benchmark. Median TFLOPS:

| Workload | Before | After | Change |
| --- | ---: | ---: | ---: |
| FP32 pedantic | 26.379272 | 26.493910 | +0.43% |
| FP16 tensor | 64.527754 | 122.869566 | +90.41% |
| BF16 tensor | 64.558792 | 122.809845 | +90.23% |
| TF32 tensor | 32.982266 | 64.157611 | +94.52% |

The offline comparison accepted both completed result sets and their recorded artifacts, runtime, settings and trial checks. It was run with the same-machine confirmation flag based on the contributor's sequence; independent confirmation that manual tuning remained unchanged is pending. Separate post-run build manifest and runtime verification files were requested. These results, alongside the firmware log, are strong evidence of increased tensor GEMM throughput on this machine; they do not establish causality in isolation, general workload gains, full numerical correctness or long-term stability.

Raw uploads remain private. Post-run ZIP SHA-256: `adac78190fc98d5918420e926b6a129dfc60c607b2dab91a226c03436652baa2`.
