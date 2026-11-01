# Large-matrix numerical spot-check, using the already installed isolated environment.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$py=Join-Path $Root 'BenchmarkEnv-v1/Scripts/python.exe'
if(!(Test-Path -LiteralPath $py)){throw 'Existing benchmark environment missing; send this error. No installation attempted.'}
$out=Join-Path $Root ('Results/christian-large-gemm-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
$source=@'
import json, math, sys
import torch
if torch.__version__ != '2.14.1+cu126' or not torch.cuda.is_available() or 'RTX 3090' not in torch.cuda.get_device_name(0):
    raise RuntimeError('Expected pinned CUDA RTX3090 environment')
torch.manual_seed(3090)
torch.backends.cuda.matmul.allow_fp16_reduced_precision_reduction = False
torch.backends.cuda.matmul.allow_bf16_reduced_precision_reduction = False
rows = []
points = [(0,0),(1,4095),(4095,1),(4095,4095),(31,97),(997,211),(2047,2048),(3021,1234)]
for name, dtype, tf32, rtol, atol in [('fp32',torch.float32,False,1e-4,1e-5),('fp16_output',torch.float16,False,0.003,1e-4),('bf16_output',torch.bfloat16,False,0.03,0.001),('tf32',torch.float32,True,0.01,0.001)]:
    torch.backends.cuda.matmul.allow_tf32 = tf32
    a = (torch.randn(4096,4096) / math.sqrt(4096)).to(dtype)
    b = (torch.randn(4096,4096) / math.sqrt(4096)).to(dtype)
    with torch.inference_mode():
        c = a.cuda() @ b.cuda()
        torch.cuda.synchronize()
        finite = bool(torch.isfinite(c).all().item())
        checks = []
        for i,j in points:
            reference = torch.dot(a[i,:].double(), b[:,j].double()).item()
            actual = c[i,j].item()
            error = abs(actual-reference)
            checks.append({'row':i,'column':j,'reference':reference,'actual':actual,'absolute_error':error,'passed':math.isfinite(actual) and error <= atol+rtol*abs(reference)})
    rows.append({'mode':name,'all_output_finite':finite,'spot_checks':checks,'passed':finite and all(x['passed'] for x in checks)})
    del a,b,c
report = {'schema':'christian-large-gemm-v1','torch':torch.__version__,'n':4096,'checks_per_mode':8,'passed':all(x['passed'] for x in rows),'results':rows,'unlock_proven':False,'interpretation':'Eight sampled entries per mode against CPU float64 using quantized inputs; not exhaustive validation or a performance comparison.'}
with open(sys.argv[1],'x',encoding='utf-8') as stream:
    json.dump(report,stream,indent=2)
print(json.dumps({'passed':report['passed'],'checks':32,'unlock_proven':False}))
'@
$runner=Join-Path $out 'check.py';[IO.File]::WriteAllText($runner,$source,[Text.UTF8Encoding]::new($false))
& $py $runner (Join-Path $out 'checks.json')
if($LASTEXITCODE -ne 0){throw ('GPU check failed; preserve '+$out+' and send error. Do not retry automatically.')}
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
[ordered]@{evidence_zip=$zip;passed=(Get-Content -LiteralPath (Join-Path $out 'checks.json') -Raw | ConvertFrom-Json).passed;settings_changed=$false;firmware_written=$false;next='Attach this ZIP even if passed is false. No reboot or unlock EFI.'} | ConvertTo-Json
