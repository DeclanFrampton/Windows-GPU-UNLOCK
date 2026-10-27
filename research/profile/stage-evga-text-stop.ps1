# GPL-2.0-only. Preserve captures and the previous USB EFI; never format or reboot.
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z]$')][string]$Drive)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$build=Join-Path $repo 'internal-boot/boot/build/evga-text-stop'
$source=Join-Path $build 'BOOTX64.EFI'
$manifest=Get-Content -LiteralPath (Join-Path $build 'manifest.json') -Raw | ConvertFrom-Json
if($manifest.Mode -ne 'evga3090-one-text-membership-stop' -or $manifest.CanUnlock -ne $false){throw 'Wrong build mode'}
$hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
if($hash -cne $manifest.EfiSha256){throw 'EFI differs from build manifest; rebuild'}
$boot=Join-Path $repo 'internal-boot/boot'
foreach($pin in $manifest.Sources){
 $path=[IO.Path]::GetFullPath((Join-Path $boot $pin.Path))
 if(!$path.StartsWith($repo+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Source pin outside repository'}
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pin.Sha256){throw "Source changed: $($pin.Path); rebuild"}
}
$system=@(Get-Partition | Where-Object {$_.IsSystem -and $_.Guid -and [guid]$_.Guid -eq [guid]$manifest.WindowsEspGuid})
if($system.Count -ne 1){throw 'Build Windows ESP pin does not match this machine'}
$letter=$Drive.ToUpperInvariant()
$volume=Get-Volume -DriveLetter $letter
$partition=@(Get-Partition -DriveLetter $letter)
if($volume.FileSystem -ne 'FAT32' -or $partition.Count -ne 1){throw 'Expected one FAT32 USB partition'}
$disk=Get-Disk -Number $partition[0].DiskNumber
if($disk.BusType -ne 'USB' -or $partition[0].IsSystem -or $partition[0].IsBoot){throw 'Target must be a USB data volume, not a Windows boot/system partition'}
$root=$letter+':\'
$captures=Join-Path $root 'RTX3090-UNLOCK'
if(!(Test-Path -LiteralPath (Join-Path $captures 'DIAG00.TXT')) -or !(Test-Path -LiteralPath (Join-Path $captures 'DIAG01.TXT'))){throw 'Original capture pair must remain on the USB'}
if(Test-Path -LiteralPath (Join-Path $captures 'EVGA-TEXT-STOP.ARMED')){throw 'An attempt is already armed; preserve evidence instead of repeating'}
$destination=Join-Path $root 'EFI/BOOT/BOOTX64.EFI'
if(!(Test-Path -LiteralPath $destination)){throw 'Expected the existing capture EFI on this USB'}
$backup=Join-Path $root 'EFI/BOOT/BOOTX64.before-evga-text-stop.efi'
if(Test-Path -LiteralPath $backup){throw 'Backup already exists; preserve it and review current USB state'}
if($PSCmdlet.ShouldProcess($destination,'Back up existing capture EFI and stage the one-call EVGA text Stop experiment')) {
 Copy-Item -LiteralPath $destination -Destination $backup
 if((Get-FileHash -LiteralPath $destination).Hash -cne (Get-FileHash -LiteralPath $backup).Hash){throw 'Backup verification failed'}
 Copy-Item -LiteralPath $source -Destination $destination -Force
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash){throw 'Staged EFI hash mismatch; do not boot'}
 "Staged $destination ($hash). Previous capture EFI saved as $backup. Captures preserved. No reboot performed."
}
