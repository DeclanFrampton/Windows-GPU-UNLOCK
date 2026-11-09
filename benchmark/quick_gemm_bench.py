"""Experimental compiler-free GEMM timings, not validated unlock evidence.

Uses system CUDA driver (nvcuda.dll) and cuBLAS (cublas64_*.dll) via ctypes.
Runs 4096 GEMM without requiring MSVC, nvcc compiler, or full CUDA Toolkit.
Inputs and numerical results are not verified by this experimental runner.
"""

import argparse
import ctypes
import math
import os
from pathlib import Path
import sys
import time


def find_cuda_libraries():
    """Locate nvcuda and cublas libraries on Windows or Linux."""
    script_dir = Path(__file__).resolve().parent
    cuda_lib = None
    cublas_lib = None

    if sys.platform == "win32":
        search_dirs = [
            script_dir,
            script_dir.parent / "tools",
            Path(os.environ.get("CUDA_PATH", "")) / "bin",
            Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32",
        ]
        for d in search_dirs:
            if d.exists():
                try:
                    os.add_dll_directory(str(d))
                except Exception:
                    pass

        try:
            cuda_lib = ctypes.WinDLL("nvcuda.dll")
        except Exception:
            pass

        candidates = [
            "cublas64_12.dll",
            "cublas64_11.dll",
            str(script_dir / "cublas64_11.dll"),
            str(script_dir.parent / "tools" / "cublas64_11.dll"),
        ]
        for c in candidates:
            try:
                cublas_lib = ctypes.WinDLL(c)
                if cublas_lib:
                    break
            except Exception:
                continue
    else:
        for c_name in ("libcuda.so", "libcuda.so.1"):
            try:
                cuda_lib = ctypes.CDLL(c_name)
                break
            except Exception:
                pass
        for cb_name in ("libcublas.so", "libcublas.so.12", "libcublas.so.11"):
            try:
                cublas_lib = ctypes.CDLL(cb_name)
                break
            except Exception:
                pass

    return cuda_lib, cublas_lib


def checked(status, operation):
    """Never turn failed CUDA/cuBLAS operations into timing results."""
    if status != 0:
        raise RuntimeError(f"{operation} failed (status {status})")


def validate_parameters(device_index, matrix_size, runs):
    if type(device_index) is not int or device_index < 0:
        raise ValueError("Device index must be a non-negative integer")
    # Existing ctypes calls pass Python allocation sizes as C int. Refuse sizes
    # that could truncate until the full API gains explicit ABI declarations.
    maximum = math.isqrt(((1 << 31) - 1) // 4)
    if type(matrix_size) is not int or not 1 <= matrix_size <= maximum:
        raise ValueError(f"Matrix dimension must be an integer from 1 to {maximum}")
    if type(runs) is not int or runs < 1:
        raise ValueError("Benchmark iterations must be a positive integer")


def run_gemm_benchmark(cuda, cublas, device_index=0, matrix_size=4096, runs=10):
    """Return timing only after successful calls; numerical verification is absent."""
    validate_parameters(device_index, matrix_size, runs)
    dev = ctypes.c_int()
    checked(cuda.cuDeviceGet(ctypes.byref(dev), device_index), "cuDeviceGet")
    name_buf = ctypes.create_string_buffer(256)
    checked(cuda.cuDeviceGetName(name_buf, 256, dev), "cuDeviceGetName")
    device_name = name_buf.value.decode("utf-8", errors="replace")
    resources = []
    try:
        ctx = ctypes.c_void_p()
        checked(cuda.cuCtxCreate_v2(ctypes.byref(ctx), 0, dev), "cuCtxCreate_v2")
        resources.append((cuda.cuCtxDestroy_v2, ctx, "cuCtxDestroy_v2"))
        handle = ctypes.c_void_p()
        checked(cublas.cublasCreate_v2(ctypes.byref(handle)), "cublasCreate_v2")
        resources.append((cublas.cublasDestroy_v2, handle, "cublasDestroy_v2"))
        checked(cublas.cublasSetMathMode(handle, 1), "cublasSetMathMode")

        n = matrix_size
        d_a, d_b, d_c = ctypes.c_uint64(), ctypes.c_uint64(), ctypes.c_uint64()
        for pointer, size in ((d_a, n * n * 2), (d_b, n * n * 2), (d_c, n * n * 4)):
            checked(cuda.cuMemAlloc_v2(ctypes.byref(pointer), size), "cuMemAlloc_v2")
            resources.append((cuda.cuMemFree_v2, pointer, "cuMemFree_v2"))
        alpha, beta = ctypes.c_float(1.0), ctypes.c_float(0.0)

        def gemm():
            checked(cublas.cublasGemmEx(
                handle, 0, 0, n, n, n,
                ctypes.byref(alpha), d_a, 2, n, d_b, 2, n,
                ctypes.byref(beta), d_c, 0, n, 68, -1), "cublasGemmEx")

        for _ in range(3):
            gemm()
        checked(cuda.cuCtxSynchronize(), "cuCtxSynchronize (warmup)")
        t0 = time.perf_counter()
        for _ in range(runs):
            gemm()
        checked(cuda.cuCtxSynchronize(), "cuCtxSynchronize (timed)")
        elapsed = time.perf_counter() - t0
        if not math.isfinite(elapsed) or elapsed <= 0:
            raise RuntimeError("Non-positive or non-finite benchmark duration")
        avg_sec = elapsed / runs
        tflops = (2 * n ** 3 / avg_sec) / 1e12
        if not math.isfinite(tflops) or tflops <= 0:
            raise RuntimeError("Non-positive or non-finite benchmark throughput")
        return {
            "device_index": device_index,
            "device_name": device_name,
            "matrix_size": matrix_size,
            "avg_ms": avg_sec * 1000.0,
            "tflops": tflops,
            "reference_checked": False,
        }
    finally:
        # Release every successfully acquired resource, even after one cleanup
        # fails. Preserve an earlier operation error rather than masking it.
        primary_error = sys.exc_info()[1]
        cleanup_errors = []
        for function, argument, operation in reversed(resources):
            try:
                checked(function(argument), operation)
            except Exception as error:
                cleanup_errors.append(str(error))
        if cleanup_errors and primary_error is None:
            raise RuntimeError("Cleanup failed: " + "; ".join(cleanup_errors))


def main():
    parser = argparse.ArgumentParser(description="Zero-dependency GEMM benchmark")
    parser.add_argument("--device", type=int, default=-1, help="Device index (-1 for all)")
    parser.add_argument("--size", type=int, default=4096, help="Matrix dimension N")
    parser.add_argument("--runs", type=int, default=10, help="Benchmark iterations")
    args = parser.parse_args()
    try:
        if args.device < -1:
            raise ValueError("Device must be -1 (all) or a non-negative index")
        validate_parameters(0 if args.device == -1 else args.device, args.size, args.runs)
    except ValueError as error:
        parser.error(str(error))

    cuda, cublas = find_cuda_libraries()
    if not cuda or not cublas:
        print("[ERROR] Could not load CUDA driver or cuBLAS library.")
        print("        An NVIDIA driver and a compatible cuBLAS library are required.")
        return 1

    if cuda.cuInit(0) != 0:
        print("[ERROR] cuInit(0) failed.")
        return 1

    count = ctypes.c_int()
    try:
        checked(cuda.cuDeviceGetCount(ctypes.byref(count)), "cuDeviceGetCount")
    except RuntimeError as error:
        print(f"[ERROR] {error}")
        return 1
    if count.value < 1:
        print("[ERROR] No NVIDIA devices found.")
        return 1

    if args.device >= count.value:
        print("[ERROR] Requested device index is outside the enumerated GPU set.")
        return 1
    devices_to_test = range(count.value) if args.device < 0 else [args.device]

    print(f"Running {args.size}x{args.size} GEMM on {len(devices_to_test)} GPU(s)...")
    print("[LIMIT] Timing only: inputs/results are not numerically verified; this is not unlock evidence.")
    failed = False
    for idx in devices_to_test:
        try:
            res = run_gemm_benchmark(cuda, cublas, device_index=idx, matrix_size=args.size, runs=args.runs)
            print(f"GPU {res['device_index']} [{res['device_name']}]: "
                  f"{res['avg_ms']:.2f} ms | {res['tflops']:.2f} TFLOPS")
        except Exception as e:
            failed = True
            print(f"GPU {idx} benchmark failed: {e}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
