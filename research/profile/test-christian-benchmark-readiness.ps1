# Installed-tool discovery only. No installs, imports of torch, GPU workloads or settings changes.
param([string]$Results='C:\GPU-Unlock\Results')
$ErrorActionPreference='Stop'
$nvcc=Get-Command nvcc -ErrorAction SilentlyContinue
$python=Get-Command python -ErrorAction SilentlyContinue
$smi=Get-Command nvidia-smi -ErrorAction SilentlyContinue
$cudaHeader=$false;$cublasLib=$false;$cublasDll=$false
if($env:CUDA_PATH){
 $cudaHeader=Test-Path -LiteralPath (Join-Path $env:CUDA_PATH 'include/cublas_v2.h') -PathType Leaf
 $cublasLib=Test-Path -LiteralPath (Join-Path $env:CUDA_PATH 'lib/x64/cublas.lib') -PathType Leaf
 $cublasDll=Test-Path -LiteralPath (Join-Path $env:CUDA_PATH 'bin/cublas64_12.dll') -PathType Leaf
}
$torchPresent=$null;$pythonCheck='not-found'
if($python){
 try{
  $answer=@(& $python -c "import importlib.util; print('TORCH_PRESENT' if importlib.util.find_spec('torch') else 'TORCH_ABSENT')" 2>&1 | ForEach-Object {"$_"})
  if($LASTEXITCODE -eq 0 -and $answer.Count -eq 1 -and $answer[0] -in @('TORCH_PRESENT','TORCH_ABSENT')){$torchPresent=$answer[0] -ceq 'TORCH_PRESENT';$pythonCheck='completed'}else{$pythonCheck='unavailable-or-unexpected-output'}
 }catch{$pythonCheck='failed'}
}
$out=Join-Path $Results ('christian-benchmark-readiness-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
$report=[ordered]@{schema='christian-benchmark-readiness-v1';nvcc_found=($null -ne $nvcc);python_found=($null -ne $python);nvidia_smi_found=($null -ne $smi);cuda_path_set=([bool]$env:CUDA_PATH);cublas_header_present=$cudaHeader;cublas_import_library_present=$cublasLib;cublas12_dll_present=$cublasDll;torch_package_present=$torchPresent;python_discovery=$pythonCheck;torch_imported=$false;gpu_workload_run=$false;software_installed=$false;settings_changed=$false}
[IO.File]::WriteAllText((Join-Path $out 'readiness.json'),($report | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
[ordered]@{evidence_zip=$zip;next='Attach this ZIP. Missing tools are a valid result; install nothing and do not reboot.'} | ConvertTo-Json
