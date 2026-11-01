# Build/stage ONE attended experimental MSI unlock transaction. Never boots or retries automatically.
param([ValidateSet('Stage','Collect')][string]$Mode='Stage',
      [ValidatePattern('^[A-Za-z]$')][string]$Drive='G',[string]$Root='C:\GPU-Unlock',[switch]$AcceptUnlockRisk)
$ErrorActionPreference='Stop'
$revision='3ea0a43316ec643d6497a91decf32094a82f3774'
$volume=Get-Volume -DriveLetter $Drive
$parts=@(Get-Partition -DriveLetter $Drive)
if($parts.Count -ne 1){throw 'Expected one USB partition'}
$disk=Get-Disk -Number $parts[0].DiskNumber
if($volume.FileSystem -ne 'FAT32' -or $disk.BusType -ne 'USB' -or $parts[0].IsSystem -or $parts[0].IsBoot){throw 'Requires your FAT32 USB; Windows/internal disks are refused'}
$usb=$Drive+':\';$capture=Join-Path $usb 'RTX3090-UNLOCK'
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$marker=Join-Path $usb 'MSI-UNLOCK.STAGED'
if($Mode -eq 'Collect'){
 if(!(Test-Path -LiteralPath $capture)){throw 'USB capture folder missing'}
 $out=Join-Path $results ('christian-unlock-result-'+[guid]::NewGuid().ToString('N'))
 [void][IO.Directory]::CreateDirectory($out)
 $collected=Join-Path $out 'RTX3090-UNLOCK';[void][IO.Directory]::CreateDirectory($collected)
 Get-ChildItem -LiteralPath $capture | Where-Object {$_.Name -ne 'ASSETS'} | Copy-Item -Destination $collected -Recurse
 if(Test-Path -LiteralPath $marker){Copy-Item -LiteralPath $marker -Destination (Join-Path $out 'stage-receipt.json')}
 $latest=Get-ChildItem -LiteralPath $collected -File -Filter 'DIAG??.TXT' | Sort-Object Name -Descending | Select-Object -First 1
 $text=if($latest){Get-Content -LiteralPath $latest.FullName -Raw}else{''}
 $success=$text.Contains('msi-unlock-transaction-complete status=0x0000000000000000') -and $text.Contains('diagnostic-result status=0x0000000000000000')
 $ss0=@([regex]::Matches($text,'msi-unlock-ss0-value status=0x0000000088888888')).Count
 $ss1=@([regex]::Matches($text,'msi-unlock-ss1-value status=0x0000000000000008')).Count
 $benchmarkAttempted=$false;$benchmarkError=$null
 if($success -and $ss0 -eq 2 -and $ss1 -eq 2){
  $benchmark=Join-Path $Root 'unlock-post-benchmark.ps1'
  $benchmarkHash='08f242dae613c8b1e9d8f5eae632590e6040e744bdc7957f448469349331570a'
  $spent=Join-Path $Root 'MSI-UNLOCK-BENCHMARK.SPENT'
  if(Test-Path -LiteralPath $spent){
   $benchmarkError='Post-benchmark already attempted; no repeat'
   try{
    $prior=[IO.Path]::GetFullPath((Get-Content -LiteralPath $spent -Raw -Encoding utf8))
    $allowed=[IO.Path]::GetFullPath($results).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    if($prior.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $prior -Leaf) -like 'christian-unlock-result-*' -and (Test-Path -LiteralPath $prior)){
     foreach($directory in @(Get-ChildItem -LiteralPath $prior -Directory -Filter 'post-benchmark-*')){
      $dest=Join-Path $out $directory.Name;[void][IO.Directory]::CreateDirectory($dest)
      foreach($name in @('measurements.json','source-hash.json','benchmark.py')){if(Test-Path -LiteralPath (Join-Path $directory.FullName $name)){Copy-Item -LiteralPath (Join-Path $directory.FullName $name) -Destination $dest}}
     }
    }
   }catch{$benchmarkError='Post-benchmark already claimed; previous report could not be read; no repeat'}
  }
  elseif((Test-Path -LiteralPath (Join-Path $Root 'BenchmarkEnv-v1/Scripts/python.exe')) -and (Test-Path -LiteralPath $benchmark) -and (Get-FileHash -LiteralPath $benchmark).Hash.ToLowerInvariant() -eq $benchmarkHash){
   try{
   $claim=[IO.File]::Open($spent,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
   try{$bytes=[Text.Encoding]::UTF8.GetBytes($out);$claim.Write($bytes,0,$bytes.Length)}finally{$claim.Dispose()}
   $benchmarkAttempted=$true;$before=@(Get-ChildItem -LiteralPath $results -Directory -Filter 'christian-torch-baseline-*' | ForEach-Object FullName)
   try{& $benchmark -Root $Root *> (Join-Path $out 'post-benchmark.txt')}catch{$benchmarkError=$_.Exception.Message}
   $new=@(Get-ChildItem -LiteralPath $results -Directory -Filter 'christian-torch-baseline-*' | Where-Object {$_.FullName -notin $before})
   foreach($directory in $new){
    $dest=Join-Path $out ('post-benchmark-'+$directory.Name);[void][IO.Directory]::CreateDirectory($dest)
    foreach($name in @('measurements.json','source-hash.json','benchmark.py')){if(Test-Path -LiteralPath (Join-Path $directory.FullName $name)){Copy-Item -LiteralPath (Join-Path $directory.FullName $name) -Destination $dest}}
   }
   }catch{$benchmarkError=$_.Exception.Message}
  }else{$benchmarkError='Existing benchmark environment or pinned runner missing/mismatched; no install/workload attempted'}
 }else{$benchmarkError='Complete successful unlock log and two target observations not present; no GPU benchmark attempted'}
 [ordered]@{efi_log_complete=$success;ss0_target_observations=$ss0;ss1_target_observations=$ss1;benchmark_attempted=$benchmarkAttempted;benchmark_error=$benchmarkError;windows_return_path='report automatic or manual';unlock_performance_proven=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'collection.json') -Encoding utf8
 Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
 Write-Output ('Attach this ZIP: '+$out+'.zip');return
}
if(!$AcceptUnlockRisk){throw 'Requires -AcceptUnlockRisk: ONE experimental transaction adds GPU MMIO and PCI writes, BME, firmware upload/execution, DMA and FLR. It may corrupt memory, hang, lose display/input or prevent Windows/GPU recovery. Recovery is unproven; errors hold with no blanket rollback or retry. Do not run unless you accept this new write/firmware/DMA/reset boundary.'}
if(@(Get-ChildItem -LiteralPath $usb -File -Filter 'MSI-*.ARMED').Count){throw 'An MSI arm file already exists. Preserve it and collect results; do not repeat.'}
if(Test-Path -LiteralPath $marker){throw 'Already staged. Do not repeat; collect results instead'}
$assets=Join-Path $Root 'Assets/ga102'
$assetSpecs=@'
[
  {"Name":"booter_load_ga102.bin","Bytes":61256,"Sha256":"056cbc064a888f80717726c54d7f64fcd68044d123870c95a74f37f4975dcaa4"},
  {"Name":"v67-ga102-610.43.03.bin","Bytes":64000,"Sha256":"2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197"},
  {"Name":"gsp_ga10x.bin","Bytes":84277400,"Sha256":"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
  {"Name":"gsp_boot_ga102.bin","Bytes":24576,"Sha256":"3df651acb174fd5f5561a1996965b192f50c5d763168446ed0d4ead19d895768"},
  {"Name":"gsp_boot_desc_ga102.bin","Bytes":84,"Sha256":"cc5a3fc1f4c47f2fe107b1b68f0176d8a448e6dec84b575e5560ccef5262bf15"}
]

'@ | ConvertFrom-Json
foreach($spec in $assetSpecs){
 $file=Join-Path $assets $spec.Name;$item=Get-Item -LiteralPath $file
 if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -ne $spec.Bytes -or (Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -ne $spec.Sha256){throw ('Local payload mismatch: '+$spec.Name)}
}
foreach($name in @('NVIDIA-LICENSE','NOTICE.md')){if(!(Test-Path -LiteralPath (Join-Path $assets $name) -PathType Leaf)){throw ('Required notice missing: '+$name)}}
$clang=Get-Command clang -ErrorAction SilentlyContinue
$lld=Get-Command lld-link -ErrorAction SilentlyContinue
if(!$clang -and (Test-Path 'C:\Program Files\LLVM\bin\clang.exe')){$clang=Get-Command 'C:\Program Files\LLVM\bin\clang.exe'}
if(!$lld -and (Test-Path 'C:\Program Files\LLVM\bin\lld-link.exe')){$lld=Get-Command 'C:\Program Files\LLVM\bin\lld-link.exe'}
if(!$clang -or !$lld){throw 'LLVM not found; send the error, install nothing'}
$python=Get-Command python -ErrorAction Stop
$work=Join-Path $Root ('Builds/member-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($work)
$archive=Join-Path $work 'source.zip'
Invoke-WebRequest -UseBasicParsing ('https://github.com/DeclanFrampton/Windows-GPU-UNLOCK/archive/'+$revision+'.zip') -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $work
$repo=Join-Path $work ('Windows-GPU-UNLOCK-'+$revision)
& (Join-Path $repo 'research/profile/build-probe.ps1') -WindowsEspGuid '3be74736-e119-47da-851a-9b1dde4d7037' -MsiRuntimeAudit -MsiMembershipAudit -MsiOneChildTest -MsiVirtualTextTest -MsiGraphicsTest -MsiEdidTest -MsiNvidiaRelease -MsiColdProbe -MsiColdFullProm -MsiAssetsDma -MsiAdmission -MsiUnlock -Clang $clang.Source -LldLink $lld.Source -Python $python.Source
$built=Join-Path $repo 'internal-boot/boot/build/msi-runtime-audit'
$m=Get-Content -LiteralPath (Join-Path $built 'manifest.json') -Raw | ConvertFrom-Json
if(!$m.MsiUnlock -or !$m.MsiAdmission -or !$m.MsiAssetsDma -or !$m.DmaMappingQualification -or !$m.MsiRuntimeAudit -or !$m.MsiMembershipAudit -or !$m.MsiOneChildTest -or !$m.MsiVirtualTextTest -or !$m.MsiGraphicsTest -or !$m.MsiEdidTest -or !$m.MsiNvidiaRelease -or !$m.MsiColdProbe -or !$m.PciMemoryEnableDisable -or !$m.MsiColdFullProm -or $m.ColdMmioReads -ne 262171 -or !$m.NvidiaStopCalled -or $m.MsiZeroChildTest -or !$m.CallsDriverStop -or !$m.CanUnlock -or !$m.CanDetach -or $m.WritesFirmwareVariables){throw 'Unexpected test mode; nothing staged'}
$benchmark=Join-Path $repo 'research/profile/run-christian-torch-baseline.ps1'
if((Get-FileHash -LiteralPath $benchmark).Hash.ToLowerInvariant() -ne '08f242dae613c8b1e9d8f5eae632590e6040e744bdc7957f448469349331570a'){throw 'Unexpected benchmark source; nothing staged'}
$postBenchmark=Join-Path $Root 'unlock-post-benchmark.ps1'
if(Test-Path -LiteralPath $postBenchmark){if((Get-FileHash -LiteralPath $postBenchmark).Hash -ne (Get-FileHash -LiteralPath $benchmark).Hash){throw 'Existing post-benchmark script differs; preserved'}}else{Copy-Item -LiteralPath $benchmark -Destination $postBenchmark}
$image=Join-Path $built 'BOOTX64.EFI';$hash=(Get-FileHash -LiteralPath $image).Hash.ToLowerInvariant()
if($hash -ne $m.EfiSha256){throw 'Built image differs from verified manifest'}
$backup=Join-Path $Root ('Backups/member-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($backup)
$target=Join-Path $usb 'EFI/BOOT/BOOTX64.EFI'
if(Test-Path -LiteralPath $target){
 Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'BOOTX64.EFI')
 if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $backup 'BOOTX64.EFI')).Hash){throw 'Backup verification failed'}
}
if(Test-Path -LiteralPath $capture){Compress-Archive -LiteralPath $capture -DestinationPath (Join-Path $backup 'previous-captures.zip')}
$usbAssets=Join-Path $capture 'ASSETS';[void][IO.Directory]::CreateDirectory($usbAssets)
foreach($spec in $assetSpecs){
 $source=Join-Path $assets $spec.Name;$dest=Join-Path $usbAssets $spec.Name
 if(Test-Path -LiteralPath $dest){
  if((Get-FileHash -LiteralPath $dest).Hash.ToLowerInvariant() -ne $spec.Sha256){throw ('Existing USB payload differs; preserved: '+$spec.Name)}
 }else{Copy-Item -LiteralPath $source -Destination $dest}
 if((Get-FileHash -LiteralPath $dest).Hash.ToLowerInvariant() -ne $spec.Sha256){throw 'USB payload readback failed; do not boot'}
}
foreach($name in @('NVIDIA-LICENSE','NOTICE.md')){
 $source=Join-Path $assets $name;$dest=Join-Path $usbAssets $name
 if(Test-Path -LiteralPath $dest){if((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $dest).Hash){throw 'Existing USB notice differs; preserved'}}else{Copy-Item -LiteralPath $source -Destination $dest}
}
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
Copy-Item -LiteralPath $image -Destination $target -Force
if((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -ne $hash){throw 'USB readback failed; do not boot'}
$receipt=[ordered]@{source_revision=$revision;efi_sha256=$hash;backup=$backup;build=$built;unlock_attempt=$true;exact_msi_admission=$true;assets_dma_qualification=$true;dma_launch=$true;calls_stop=$true;unlock=$true;automatic_reboot=$false}
$receipt|ConvertTo-Json|Set-Content -LiteralPath $marker -Encoding utf8
Copy-Item -LiteralPath (Join-Path $built 'manifest.json') -Destination (Join-Path $backup 'manifest.json')
Copy-Item -LiteralPath (Join-Path $built 'pe-verification.json') -Destination (Join-Path $backup 'pe-verification.json')
[IO.File]::WriteAllText((Join-Path $usb 'MSI-UNLOCK.ARMED'),$hash,[Text.UTF8Encoding]::new($false))
Write-Output 'Ready. Shut down and boot USB once. No keys needed. If Windows is absent after 10 minutes: power off, remove USB, choose Windows Boot Manager. Do not retry.'
