"""GPU-free CUDA/cuBLAS failure tests. No native library is loaded."""
import contextlib
import io
import unittest
from unittest.mock import MagicMock, patch

import quick_gemm_bench as bench


def fake_apis():
    cuda, cublas = MagicMock(), MagicMock()
    for name in ('cuDeviceGet', 'cuDeviceGetName', 'cuCtxCreate_v2', 'cuMemAlloc_v2',
                 'cuCtxSynchronize', 'cuMemFree_v2', 'cuCtxDestroy_v2', 'cuInit', 'cuDeviceGetCount'):
        getattr(cuda, name).return_value = 0
    for name in ('cublasCreate_v2', 'cublasSetMathMode', 'cublasGemmEx', 'cublasDestroy_v2'):
        getattr(cublas, name).return_value = 0
    return cuda, cublas


class QuickFailureTests(unittest.TestCase):
    def run_fake(self, cuda, cublas, *, duration=1.0, **kwargs):
        with patch.object(bench.time, 'perf_counter', side_effect=[100.0, 100.0 + duration]), \
                patch.object(bench.time, 'time', side_effect=[100.0, 100.0 + duration]):
            return bench.run_gemm_benchmark(cuda, cublas, **kwargs)

    def test_each_preparation_error_refuses_a_result(self):
        for which, name in (('cuda', 'cuDeviceGet'), ('cuda', 'cuDeviceGetName'),
                            ('cuda', 'cuCtxCreate_v2'), ('cublas', 'cublasCreate_v2'),
                            ('cublas', 'cublasSetMathMode')):
            with self.subTest(name=name):
                cuda, cublas = fake_apis()
                getattr(cuda if which == 'cuda' else cublas, name).return_value = 7
                with self.assertRaisesRegex(RuntimeError, name):
                    self.run_fake(cuda, cublas)
                cublas.cublasGemmEx.assert_not_called()
                if name == 'cublasCreate_v2':
                    cuda.cuCtxDestroy_v2.assert_called_once()
                    cublas.cublasDestroy_v2.assert_not_called()

    def test_failed_allocation_frees_only_successful_allocations(self):
        for prior in range(3):
            with self.subTest(prior_allocations=prior):
                cuda, cublas = fake_apis()
                def allocate(pointer, size):
                    index = cuda.cuMemAlloc_v2.call_count - 1
                    if index == prior:
                        return 2
                    pointer._obj.value = (index + 1) * 4096
                    return 0

                cuda.cuMemAlloc_v2.side_effect = allocate
                with self.assertRaisesRegex(RuntimeError, 'cuMemAlloc_v2'):
                    self.run_fake(cuda, cublas)
                self.assertEqual(cuda.cuMemFree_v2.call_count, prior)
                self.assertEqual([call.args[0].value for call in cuda.cuMemFree_v2.call_args_list],
                                 [i * 4096 for i in range(prior, 0, -1)])
                cublas.cublasDestroy_v2.assert_called_once()
                cuda.cuCtxDestroy_v2.assert_called_once()
                cublas.cublasGemmEx.assert_not_called()

    def test_warmup_and_timed_gemm_errors_refuse_a_result(self):
        for prior in (0, 2, 3, 5):
            with self.subTest(prior_calls=prior):
                cuda, cublas = fake_apis()
                cublas.cublasGemmEx.side_effect = [0] * prior + [7]
                with self.assertRaisesRegex(RuntimeError, 'cublasGemmEx'):
                    self.run_fake(cuda, cublas, runs=3)
                self.assertEqual(cuda.cuMemFree_v2.call_count, 3)

    def test_both_synchronization_errors_refuse_a_result(self):
        for codes in ([700, 0], [0, 700]):
            with self.subTest(codes=codes):
                cuda, cublas = fake_apis()
                cuda.cuCtxSynchronize.side_effect = codes
                with self.assertRaisesRegex(RuntimeError, 'cuCtxSynchronize'):
                    self.run_fake(cuda, cublas)

    def test_cleanup_errors_refuse_result_but_finish_cleanup(self):
        for which, name in (('cuda', 'cuMemFree_v2'), ('cublas', 'cublasDestroy_v2'),
                            ('cuda', 'cuCtxDestroy_v2')):
            with self.subTest(name=name):
                cuda, cublas = fake_apis()
                getattr(cuda if which == 'cuda' else cublas, name).return_value = 9
                with self.assertRaisesRegex(RuntimeError, 'Cleanup failed:.*' + name):
                    self.run_fake(cuda, cublas)
                self.assertEqual(cuda.cuMemFree_v2.call_count, 3)
                cublas.cublasDestroy_v2.assert_called_once()
                cuda.cuCtxDestroy_v2.assert_called_once()

    def test_cleanup_does_not_mask_primary_failure(self):
        cuda, cublas = fake_apis()
        cublas.cublasGemmEx.return_value = 7
        cuda.cuMemFree_v2.return_value = 2
        cublas.cublasDestroy_v2.return_value = 9
        with self.assertRaisesRegex(RuntimeError, '^cublasGemmEx failed'):
            self.run_fake(cuda, cublas)
        self.assertEqual(cuda.cuMemFree_v2.call_count, 3)
        cuda.cuCtxDestroy_v2.assert_called_once()

    def test_python_cleanup_exception_does_not_skip_remaining_resources(self):
        cuda, cublas = fake_apis()
        cuda.cuMemFree_v2.side_effect = OSError('mock cleanup failure')
        with self.assertRaisesRegex(RuntimeError, 'Cleanup failed:.*mock cleanup failure'):
            self.run_fake(cuda, cublas)
        self.assertEqual(cuda.cuMemFree_v2.call_count, 3)
        cublas.cublasDestroy_v2.assert_called_once()
        cuda.cuCtxDestroy_v2.assert_called_once()

    def test_invalid_parameters_never_call_gpu_apis(self):
        cases = ({'device_index': -1}, {'device_index': True}, {'matrix_size': 0},
                 {'matrix_size': -1}, {'matrix_size': 23171}, {'matrix_size': True},
                 {'runs': 0}, {'runs': -1}, {'runs': True})
        for parameters in cases:
            with self.subTest(parameters=parameters):
                cuda, cublas = fake_apis()
                with self.assertRaises(ValueError):
                    self.run_fake(cuda, cublas, **parameters)
                self.assertEqual(cuda.mock_calls, [])
                self.assertEqual(cublas.mock_calls, [])

    def test_invalid_durations_refuse_results(self):
        for duration in (0.0, -1.0, float('nan'), float('inf')):
            with self.subTest(duration=duration):
                cuda, cublas = fake_apis()
                with self.assertRaisesRegex(RuntimeError, 'duration'):
                    self.run_fake(cuda, cublas, duration=duration)
                self.assertEqual(cuda.cuMemFree_v2.call_count, 3)

    def test_success_reports_timing_without_claiming_numerical_validation(self):
        cuda, cublas = fake_apis()
        result = self.run_fake(cuda, cublas, runs=10)
        self.assertAlmostEqual(result['avg_ms'], 100.0)
        self.assertAlmostEqual(result['tflops'], 2 * 4096 ** 3 * 10 / 1e12)
        self.assertIs(result['reference_checked'], False)
        self.assertEqual(cublas.cublasGemmEx.call_count, 13)
        self.assertEqual(cuda.cuCtxSynchronize.call_count, 2)


class QuickCliTests(unittest.TestCase):
    def run_cli(self, *, count=1, count_error=0, benchmark_error=None, arguments=()):
        cuda, cublas = fake_apis()

        def count_devices(pointer):
            pointer._obj.value = count
            return count_error

        cuda.cuDeviceGetCount.side_effect = count_devices
        with patch.object(bench, 'find_cuda_libraries', return_value=(cuda, cublas)), \
                patch.object(bench, 'run_gemm_benchmark', side_effect=benchmark_error,
                             return_value={'device_index': 0, 'device_name': 'mock', 'avg_ms': 1, 'tflops': 1}) as run, \
                patch.object(bench.sys, 'argv', ['quick_gemm_bench.py', *arguments]), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            status = bench.main()
        return status, output.getvalue(), run

    def test_all_device_failures_exit_nonzero(self):
        status, output, run = self.run_cli(count=2, benchmark_error=RuntimeError('simulated error'))
        self.assertEqual(status, 1)
        self.assertEqual(run.call_count, 2)
        self.assertNotIn('TFLOPS', output)

    def test_device_count_failure_refuses_benchmark(self):
        status, output, run = self.run_cli(count_error=700)
        self.assertEqual(status, 1)
        self.assertIn('cuDeviceGetCount', output)
        run.assert_not_called()

    def test_later_success_does_not_hide_an_earlier_device_failure(self):
        result = {'device_index': 1, 'device_name': 'mock', 'avg_ms': 1, 'tflops': 1}
        status, output, run = self.run_cli(count=2, benchmark_error=[RuntimeError('failed first'), result])
        self.assertEqual(status, 1)
        self.assertEqual(run.call_count, 2)
        self.assertIn('TFLOPS', output)
        self.assertIn('failed first', output)

    def test_no_devices_and_out_of_range_index_refuse_benchmark(self):
        for count, arguments in ((0, ()), (1, ('--device', '1'))):
            with self.subTest(count=count, arguments=arguments):
                status, _, run = self.run_cli(count=count, arguments=arguments)
                self.assertEqual(status, 1)
                run.assert_not_called()

    def test_cli_success_keeps_numerical_limit_visible(self):
        status, output, _ = self.run_cli()
        self.assertEqual(status, 0)
        self.assertIn('not numerically verified', output)

    def test_invalid_cli_arguments_do_not_load_libraries(self):
        for arguments in (('--size', '0'), ('--runs', '0'), ('--device', '-2')):
            with self.subTest(arguments=arguments), \
                    patch.object(bench, 'find_cuda_libraries') as load, \
                    patch.object(bench.sys, 'argv', ['quick_gemm_bench.py', *arguments]), \
                    contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as result:
                    bench.main()
                self.assertEqual(result.exception.code, 2)
                load.assert_not_called()


if __name__ == '__main__':
    unittest.main()
