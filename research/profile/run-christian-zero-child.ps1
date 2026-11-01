# Stage the reviewed zero-child method test EFI, or collect its output. Never reboot automatically.
param([ValidateSet('Stage','Collect')][string]$Mode='Stage',[string]$Drive,[string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$expected='d5cd327ab59d18436e01461cdaa974db4a2614204c5d47b726b6a466deddfc60'
if(!$Drive){$Drive=Read-Host 'Enter the USB drive letter (for example D)'}
$Drive=$Drive.Trim().TrimEnd(':','\')
if($Drive -notmatch '^[A-Za-z]$'){throw 'Enter one drive letter only'}
$volume=Get-Volume -DriveLetter $Drive
$partition=Get-Partition -DriveLetter $Drive
$disk=$partition | Get-Disk
if($volume.FileSystem -ne 'FAT32' -or $disk.BusType -ne 'USB' -or $partition.IsSystem -or $partition.IsBoot){throw 'Requires a FAT32 USB, never a Windows/system partition'}
$usb=$Drive+':\'
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
if($Mode -eq 'Collect'){
 $capture=Join-Path $usb 'RTX3090-UNLOCK'
 if(!(Test-Path -LiteralPath $capture)){throw 'No RTX3090-UNLOCK capture folder on this USB'}
 $zip=Join-Path $results ('christian-zero-child-result-'+[guid]::NewGuid().ToString('N')+'.zip')
 Compress-Archive -LiteralPath $capture -DestinationPath $zip
 Write-Output ('Attach this ZIP: '+$zip);return
}
$candidates=@(Get-ChildItem -LiteralPath $results -Filter 'christian-zero-child-build-*.zip' -File | Sort-Object LastWriteTimeUtc -Descending)
if(!$candidates.Count){throw 'No zero-child build ZIP in C:\GPU-Unlock\Results'}
$work=Join-Path $Root ('AuditStage/'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($work)
Expand-Archive -LiteralPath $candidates[0].FullName -DestinationPath $work
$images=@(Get-ChildItem -LiteralPath $work -Recurse -Filter BOOTX64.EFI -File)
if($images.Count -ne 1 -or (Get-FileHash -LiteralPath $images[0].FullName).Hash.ToLowerInvariant() -ne $expected){throw 'Build differs from the reviewed Christian image; stop and send the error'}
$manifest=Get-Content -LiteralPath (Join-Path $images[0].DirectoryName 'manifest.json') -Raw | ConvertFrom-Json
if(!$manifest.MsiRuntimeAudit -or !$manifest.MsiZeroChildTest -or !$manifest.CallsDriverStop -or $manifest.CanUnlock -or $manifest.CanDetach -or $manifest.WritesFirmwareVariables){throw 'Unexpected audit manifest'}
$marker=Join-Path $usb 'MSI-ZERO-CHILD.STAGED'
if(Test-Path -LiteralPath $marker){throw 'This test was already staged. Do not repeat it; collect results instead.'}
$backup=Join-Path $Root ('Backups/audit-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($backup)
$target=Join-Path $usb 'EFI/BOOT/BOOTX64.EFI'
if(Test-Path -LiteralPath $target){
 Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'BOOTX64.EFI')
 if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $backup 'BOOTX64.EFI')).Hash){throw 'Original EFI backup verification failed'}
}
$capture=Join-Path $usb 'RTX3090-UNLOCK'
if(Test-Path -LiteralPath $capture){Compress-Archive -LiteralPath $capture -DestinationPath (Join-Path $backup 'previous-captures.zip')}
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
Copy-Item -LiteralPath $images[0].FullName -Destination $target -Force
if((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -ne $expected){throw 'USB readback mismatch. Do not boot it'}
[IO.File]::WriteAllText($marker,$expected,[Text.UTF8Encoding]::new($false))
[ordered]@{staged=$true;sha256=$expected;backup=$backup;automatic_reboot=$false;unlock=$false} | ConvertTo-Json
Write-Output 'Ready: shut down, boot this USB ONCE from the firmware boot menu. After Windows returns, run this script with -Mode Collect and the same USB letter.'
