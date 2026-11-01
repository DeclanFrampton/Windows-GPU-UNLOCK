# Build/stage one attended full cold PROM hash comparison after the proven release stages. No automatic boot or rollback.
param([ValidateSet('Stage','Collect')][string]$Mode='Stage',
      [ValidatePattern('^[A-Za-z]$')][string]$Drive='G',[string]$Root='C:\GPU-Unlock',[switch]$AcceptRisk)
$ErrorActionPreference='Stop'
$revision='4c2b7e140c9793bdcf083680dd462d3b4f4bd2d2'
$volume=Get-Volume -DriveLetter $Drive
$parts=@(Get-Partition -DriveLetter $Drive)
if($parts.Count -ne 1){throw 'Expected one USB partition'}
$disk=Get-Disk -Number $parts[0].DiskNumber
if($volume.FileSystem -ne 'FAT32' -or $disk.BusType -ne 'USB' -or $parts[0].IsSystem -or $parts[0].IsBoot){throw 'Requires your FAT32 USB; Windows/internal disks are refused'}
$usb=$Drive+':\';$capture=Join-Path $usb 'RTX3090-UNLOCK'
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$marker=Join-Path $usb 'MSI-COLD-FULL-PROM.STAGED'
if($Mode -eq 'Collect'){
 if(!(Test-Path -LiteralPath $capture)){throw 'USB capture folder missing'}
 $out=Join-Path $results ('christian-cold-full-prom-result-'+[guid]::NewGuid().ToString('N'))
 [void][IO.Directory]::CreateDirectory($out)
 Copy-Item -LiteralPath $capture -Destination (Join-Path $out 'RTX3090-UNLOCK') -Recurse
 if(Test-Path -LiteralPath $marker){Copy-Item -LiteralPath $marker -Destination (Join-Path $out 'stage-receipt.json')}
 Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
 Write-Output ('Attach this ZIP: '+$out+'.zip');return
}
if(!$AcceptRisk){throw 'Stage requires -AcceptRisk: prior release stages plus memory-decode enable,262162 live MMIO reads and normal decode-off may lose display/input, hang or prevent Windows boot; recovery is unproven. No automatic retry or rollback.'}
if(Test-Path -LiteralPath (Join-Path $usb 'MSI-COLD-PROBE.ARMED')){throw 'An arm file already exists. Preserve it and collect results; do not repeat.'}
if(Test-Path -LiteralPath $marker){throw 'Already staged. Do not repeat; collect results instead'}
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
& (Join-Path $repo 'research/profile/build-probe.ps1') -WindowsEspGuid '3be74736-e119-47da-851a-9b1dde4d7037' -MsiRuntimeAudit -MsiMembershipAudit -MsiOneChildTest -MsiVirtualTextTest -MsiGraphicsTest -MsiEdidTest -MsiNvidiaRelease -MsiColdProbe -MsiColdFullProm -Clang $clang.Source -LldLink $lld.Source -Python $python.Source
$built=Join-Path $repo 'internal-boot/boot/build/msi-runtime-audit'
$m=Get-Content -LiteralPath (Join-Path $built 'manifest.json') -Raw | ConvertFrom-Json
if(!$m.MsiRuntimeAudit -or !$m.MsiMembershipAudit -or !$m.MsiOneChildTest -or !$m.MsiVirtualTextTest -or !$m.MsiGraphicsTest -or !$m.MsiEdidTest -or !$m.MsiNvidiaRelease -or !$m.MsiColdProbe -or !$m.PciMemoryEnableDisable -or !$m.MsiColdFullProm -or $m.ColdMmioReads -ne 262162 -or !$m.NvidiaStopCalled -or $m.MsiZeroChildTest -or !$m.CallsDriverStop -or $m.CanUnlock -or !$m.CanDetach -or $m.WritesFirmwareVariables){throw 'Unexpected test mode; nothing staged'}
$image=Join-Path $built 'BOOTX64.EFI';$hash=(Get-FileHash -LiteralPath $image).Hash.ToLowerInvariant()
if($hash -ne $m.EfiSha256){throw 'Built image differs from verified manifest'}
$backup=Join-Path $Root ('Backups/member-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($backup)
$target=Join-Path $usb 'EFI/BOOT/BOOTX64.EFI'
if(Test-Path -LiteralPath $target){
 Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'BOOTX64.EFI')
 if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $backup 'BOOTX64.EFI')).Hash){throw 'Backup verification failed'}
}
if(Test-Path -LiteralPath $capture){Compress-Archive -LiteralPath $capture -DestinationPath (Join-Path $backup 'previous-captures.zip')}
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
Copy-Item -LiteralPath $image -Destination $target -Force
if((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -ne $hash){throw 'USB readback failed; do not boot'}
$receipt=[ordered]@{source_revision=$revision;efi_sha256=$hash;backup=$backup;build=$built;calls_stop=$true;unlock=$false;automatic_reboot=$false}
$receipt|ConvertTo-Json|Set-Content -LiteralPath $marker -Encoding utf8
Copy-Item -LiteralPath (Join-Path $built 'manifest.json') -Destination (Join-Path $backup 'manifest.json')
Copy-Item -LiteralPath (Join-Path $built 'pe-verification.json') -Destination (Join-Path $backup 'pe-verification.json')
[IO.File]::WriteAllText((Join-Path $usb 'MSI-COLD-PROBE.ARMED'),$hash,[Text.UTF8Encoding]::new($false))
Write-Output 'Ready. Shut down and boot USB once. No keys needed. If Windows is absent after 2 minutes: power off, remove USB, choose Windows Boot Manager. Do not retry.'
