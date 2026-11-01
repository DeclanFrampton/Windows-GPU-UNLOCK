# Build/stage payload residency plus one common-buffer mapping qualification. No DMA launch or unlock.
param([ValidateSet('Stage','Collect')][string]$Mode='Stage',
      [ValidatePattern('^[A-Za-z]$')][string]$Drive='G',[string]$Root='C:\GPU-Unlock',[switch]$AcceptRisk)
$ErrorActionPreference='Stop'
$revision='baed28efde9e86944e754c6246841cc85d5a4d9d'
$volume=Get-Volume -DriveLetter $Drive
$parts=@(Get-Partition -DriveLetter $Drive)
if($parts.Count -ne 1){throw 'Expected one USB partition'}
$disk=Get-Disk -Number $parts[0].DiskNumber
if($volume.FileSystem -ne 'FAT32' -or $disk.BusType -ne 'USB' -or $parts[0].IsSystem -or $parts[0].IsBoot){throw 'Requires your FAT32 USB; Windows/internal disks are refused'}
$usb=$Drive+':\';$capture=Join-Path $usb 'RTX3090-UNLOCK'
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$marker=Join-Path $usb 'MSI-ASSETS-DMA.STAGED'
if($Mode -eq 'Collect'){
 if(!(Test-Path -LiteralPath $capture)){throw 'USB capture folder missing'}
 $out=Join-Path $results ('christian-assets-dma-result-'+[guid]::NewGuid().ToString('N'))
 [void][IO.Directory]::CreateDirectory($out)
 $collected=Join-Path $out 'RTX3090-UNLOCK';[void][IO.Directory]::CreateDirectory($collected)
 Get-ChildItem -LiteralPath $capture | Where-Object {$_.Name -ne 'ASSETS'} | Copy-Item -Destination $collected -Recurse
 if(Test-Path -LiteralPath $marker){Copy-Item -LiteralPath $marker -Destination (Join-Path $out 'stage-receipt.json')}
 Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
 Write-Output ('Attach this ZIP: '+$out+'.zip');return
}
if(!$AcceptRisk){throw 'Stage requires -AcceptRisk: repeats release/cold reads, retains five payloads and allocates/maps/unmaps/frees one GSP-sized common buffer. Firmware mapping may hang, lose display/input or prevent Windows. Errors hold without rollback and may retain memory/mappings until manual power-off. Recovery is unproven. No DMA launch, BME enable or unlock is added.'}
if(Test-Path -LiteralPath (Join-Path $usb 'MSI-COLD-PROBE.ARMED')){throw 'An arm file already exists. Preserve it and collect results; do not repeat.'}
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
& (Join-Path $repo 'research/profile/build-probe.ps1') -WindowsEspGuid '3be74736-e119-47da-851a-9b1dde4d7037' -MsiRuntimeAudit -MsiMembershipAudit -MsiOneChildTest -MsiVirtualTextTest -MsiGraphicsTest -MsiEdidTest -MsiNvidiaRelease -MsiColdProbe -MsiColdFullProm -MsiAssetsDma -Clang $clang.Source -LldLink $lld.Source -Python $python.Source
$built=Join-Path $repo 'internal-boot/boot/build/msi-runtime-audit'
$m=Get-Content -LiteralPath (Join-Path $built 'manifest.json') -Raw | ConvertFrom-Json
if(!$m.MsiAssetsDma -or !$m.DmaMappingQualification -or !$m.MsiRuntimeAudit -or !$m.MsiMembershipAudit -or !$m.MsiOneChildTest -or !$m.MsiVirtualTextTest -or !$m.MsiGraphicsTest -or !$m.MsiEdidTest -or !$m.MsiNvidiaRelease -or !$m.MsiColdProbe -or !$m.PciMemoryEnableDisable -or !$m.MsiColdFullProm -or $m.ColdMmioReads -ne 262162 -or !$m.NvidiaStopCalled -or $m.MsiZeroChildTest -or !$m.CallsDriverStop -or $m.CanUnlock -or !$m.CanDetach -or $m.WritesFirmwareVariables){throw 'Unexpected test mode; nothing staged'}
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
$receipt=[ordered]@{source_revision=$revision;efi_sha256=$hash;backup=$backup;build=$built;assets_dma_qualification=$true;dma_launch=$false;calls_stop=$true;unlock=$false;automatic_reboot=$false}
$receipt|ConvertTo-Json|Set-Content -LiteralPath $marker -Encoding utf8
Copy-Item -LiteralPath (Join-Path $built 'manifest.json') -Destination (Join-Path $backup 'manifest.json')
Copy-Item -LiteralPath (Join-Path $built 'pe-verification.json') -Destination (Join-Path $backup 'pe-verification.json')
[IO.File]::WriteAllText((Join-Path $usb 'MSI-COLD-PROBE.ARMED'),$hash,[Text.UTF8Encoding]::new($false))
Write-Output 'Ready. Shut down and boot USB once. No keys needed. If Windows is absent after 5 minutes: power off, remove USB, choose Windows Boot Manager. Do not retry.'
