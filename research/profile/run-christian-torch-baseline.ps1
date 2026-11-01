# Isolated, pinned PyTorch benchmark. Installs only inside this test's venv; no tuning/reboot.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$envDir=Join-Path $Root 'BenchmarkEnv-v1'
$py=Join-Path $envDir 'Scripts/python.exe'
if(!(Test-Path -LiteralPath $envDir)){
 & python -m venv $envDir
 if($LASTEXITCODE -ne 0){throw 'Could not create isolated environment; send error'}
 & $py -m pip install --disable-pip-version-check 'torch==2.14.1+cu126' --index-url https://download.pytorch.org/whl/cu126
 if($LASTEXITCODE -ne 0){throw 'PyTorch installation failed; preserve folder and send error'}
}
if(!(Test-Path -LiteralPath $py)){throw 'Partial environment exists; preserve it and report. Do not delete/retry automatically.'}
$out=Join-Path $Root ('Results/christian-torch-baseline-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($out)
$source=@'
import json, math, statistics, sys, time
import torch
if torch.__version__ != '2.14.1+cu126':
    raise RuntimeError('Unexpected torch version; preserve environment')
if not torch.cuda.is_available():
    raise RuntimeError('CUDA unavailable; no benchmark performed')
props = torch.cuda.get_device_properties(0)
if 'RTX 3090' not in props.name:
    raise RuntimeError('Expected RTX3090; no workload performed')
torch.manual_seed(3090)
torch.backends.cuda.matmul.allow_fp16_reduced_precision_reduction = False
torch.backends.cuda.matmul.allow_bf16_reduced_precision_reduction = False
modes = [('fp32', torch.float32, False, 1e-4), ('fp16_output', torch.float16, False, 0.003), ('bf16_output', torch.bfloat16, False, 0.03), ('tf32', torch.float32, True, 0.01)]
rows = []
for name, dtype, tf32, tolerance in modes:
    torch.backends.cuda.matmul.allow_tf32 = tf32
    x = torch.randn(128, 128) / math.sqrt(128)
    y = torch.randn(128, 128) / math.sqrt(128)
    reference = x.double() @ y.double()
    actual = (x.cuda().to(dtype) @ y.cuda().to(dtype)).double().cpu()
    if not torch.isfinite(actual).all() or not torch.allclose(actual, reference, rtol=tolerance, atol=tolerance):
        raise RuntimeError('Reference check failed: ' + name)
    a = torch.randn(4096, 4096, device='cuda', dtype=dtype)
    b = torch.randn(4096, 4096, device='cuda', dtype=dtype)
    output = torch.empty_like(a)
    with torch.inference_mode():
        for _ in range(10):
            torch.mm(a, b, out=output)
        torch.cuda.synchronize()
        trials = []
        for _ in range(3):
            samples = []
            for _ in range(10):
                start, end = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
                start.record()
                torch.mm(a, b, out=output)
                end.record()
                end.synchronize()
                ms = start.elapsed_time(end)
                if not math.isfinite(ms) or ms <= 0:
                    raise RuntimeError('Invalid GPU timing')
                samples.append(ms)
            trials.append(2 * 4096**3 / (statistics.median(samples) * 1e9))
    if not torch.isfinite(output).all():
        raise RuntimeError('Nonfinite benchmark output')
    rows.append({'mode': name, 'n': 4096, 'samples_per_trial': 10, 'trial_tflops': trials, 'median_tflops': statistics.median(trials), 'reference_checked_n': 128, 'allow_tf32': tf32})
    del a, b, output
report = {'schema': 'christian-torch-baseline-v1', 'torch': torch.__version__, 'cuda_runtime': torch.version.cuda, 'gpu': props.name, 'compute_capability': [props.major, props.minor], 'device_total_bytes': props.total_memory, 'measurements': rows, 'unlock_proven': False, 'interpretation': 'Current-state PyTorch GEMM baseline. FP16/BF16 have reduced-precision output; not directly comparable to the cuBLAS FP32-accumulation benchmark. No speedup inferred.'}
with open(sys.argv[1], 'x', encoding='utf-8') as stream:
    json.dump(report, stream, indent=2)
print(json.dumps(report, indent=2))
'@
$runner=Join-Path $out 'benchmark.py'
[IO.File]::WriteAllText($runner,$source,[Text.UTF8Encoding]::new($false))
Get-FileHash -LiteralPath $runner -Algorithm SHA256 | Select-Object Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'source-hash.json')
& $py $runner (Join-Path $out 'measurements.json')
if($LASTEXITCODE -ne 0){throw ('Benchmark failed. Preserve '+$out+' and send error; do not rerun automatically.')}
& $py -m pip freeze | Set-Content -LiteralPath (Join-Path $out 'packages.txt')
if($LASTEXITCODE -ne 0){throw 'Could not capture package provenance; preserve output and report'}
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
[ordered]@{evidence_zip=$zip;gpu_workload_run=$true;settings_changed=$false;firmware_written=$false;next='Attach this ZIP. Report whether any unlock EFI ran before this benchmark; no reboot required.'} | ConvertTo-Json
