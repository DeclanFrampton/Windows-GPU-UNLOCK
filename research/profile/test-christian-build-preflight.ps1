# Saved-evidence checks only. No GPU/firmware calls or EFI staging.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
function Read-LatestChristianReport([string]$Name){
 $files=@(Get-ChildItem -LiteralPath (Join-Path $Root 'Results') -Recurse -File -Filter $Name | Sort-Object LastWriteTime -Descending)
 if(!$files.Count){throw ('Missing '+$Name+'; keep existing folders and send this error')}
 Get-Content -LiteralPath $files[0].FullName -Raw | ConvertFrom-Json
}
$baseline=Read-LatestChristianReport 'baseline.json'
$boot=Read-LatestChristianReport 'boot-target.json'
$measure=Read-LatestChristianReport 'measurements.json'
$numeric=Read-LatestChristianReport 'checks.json'
$checks=[ordered]@{}
$checks.capture00=((Get-FileHash -LiteralPath (Join-Path $Root 'Captures/DIAG00.TXT') -Algorithm SHA256).Hash -ieq 'fb577ca6181e512291cab47d189d82305db01a873f478260cf10ef8a262edef6')
$checks.capture01=((Get-FileHash -LiteralPath (Join-Path $Root 'Captures/DIAG01.TXT') -Algorithm SHA256).Hash -ieq 'bb94621183f21b7e5e86a9fdb809bb4b6f8ceeaa889fe7a583ac67412859935d')
$checks.msi_gpu=(@($baseline.gpus | Where-Object pci_identity -CEQ 'VEN_10DE&DEV_2204&SUBSYS_38811462').Count -eq 1)
$checks.board=($baseline.board.Product -ceq 'PRIME H510M-K R2.0' -and $baseline.bios.SMBIOSBIOSVersion -ceq '0802')
$checks.esp=($boot.windows_esp_guid -ceq '3be74736-e119-47da-851a-9b1dde4d7037' -and $boot.filesystem -ceq 'FAT32' -and $boot.disk_bus_type -ne 'USB')
$checks.bootloader=($boot.windows_bootloader_sha256 -ceq '3f8a4cbbc97b89836df92c4895236be1fac4a127665420d90509e897a7298511' -and !$boot.bootloader_read_error)
$checks.secure_boot_report=($boot.secure_boot_enabled -is [bool] -and $boot.secure_boot_enabled -eq $false -and !$boot.secure_boot_error)
$checks.benchmark=($measure.schema -ceq 'christian-torch-baseline-v1' -and $measure.torch -ceq '2.14.1+cu126' -and $measure.measurements.Count -eq 4)
$checks.numeric=($numeric.schema -ceq 'christian-large-gemm-v1' -and $numeric.passed -eq $true -and $numeric.results.Count -eq 4)
$passed=@($checks.Values | Where-Object {$_ -ne $true}).Count -eq 0
$out=Join-Path $Root ('Results/christian-build-preflight-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
$report=[ordered]@{schema='christian-build-preflight-v1';checks=$checks;saved_inputs_match=$passed;live_state_rechecked=$false;driver_release_qualified=$false;unlock_qualified=$false;gpu_accessed=$false;firmware_written=$false;interpretation='Saved input consistency only; not permission to boot an unlock EFI or proof of current hardware state.'}
[IO.File]::WriteAllText((Join-Path $out 'preflight.json'),($report | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
[ordered]@{saved_inputs_match=$passed;evidence_zip=$zip;next='Attach this ZIP even if false. Do not reboot, change settings or run an unlock EFI.'} | ConvertTo-Json
