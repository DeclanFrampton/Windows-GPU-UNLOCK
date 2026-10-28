# GPL-2.0-only. Preserve captures and the previous USB EFI; never format or reboot.
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z]$')][string]$Drive)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$build=Join-Path $repo 'internal-boot/boot/build/evga-text-stop'
$source=Join-Path $build 'BOOTX64.EFI'
$manifest=Get-Content -LiteralPath (Join-Path $build 'manifest.json') -Raw | ConvertFrom-Json
if($manifest.Mode -notin @('evga3090-one-text-membership-stop','evga3090-two-text-stops','evga3090-three-consumer-stops','evga3090-four-consumer-stops','evga3090-six-consumer-stops','evga3090-nvidia-preflight','evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop') -or $manifest.CanUnlock -ne $false){throw 'Wrong build mode'}
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
$attempt=if($manifest.Mode -eq 'evga3090-nvidia-parent-stop'){'EVGA-NVIDIA-PARENT.ARMED'}elseif($manifest.Mode -eq 'evga3090-nvidia-three-child-stop'){'EVGA-NVIDIA-CHILDREN.ARMED'}elseif($manifest.Mode -eq 'evga3090-nvidia-preflight'){'EVGA-NVIDIA-AUDIT.ARMED'}elseif($manifest.Mode -eq 'evga3090-six-consumer-stops'){'EVGA-EDID-SIBLINGS.ARMED'}elseif($manifest.Mode -eq 'evga3090-four-consumer-stops'){'EVGA-EDID-RELEASE.ARMED'}elseif($manifest.Mode -eq 'evga3090-three-consumer-stops'){'EVGA-GFX-RELEASE.ARMED'}elseif($manifest.Mode -eq 'evga3090-two-text-stops'){'EVGA-TEXT-RELEASE.ARMED'}else{'EVGA-TEXT-STOP.ARMED'}
if(Test-Path -LiteralPath (Join-Path $captures $attempt)){throw 'An attempt is already armed; preserve evidence instead of repeating'}
if($manifest.Mode -in @('evga3090-two-text-stops','evga3090-three-consumer-stops','evga3090-four-consumer-stops','evga3090-six-consumer-stops','evga3090-nvidia-preflight','evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop')) {
 $baseline=Join-Path $captures 'EVGA05.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'cbbfad6aadb858cdc6311f656c819e6707e52f274e8e0959df4348c51fbbec1a'){throw 'Expected reviewed EVGA05 baseline; preserve captures and send the error'}
}
if($manifest.Mode -in @('evga3090-three-consumer-stops','evga3090-four-consumer-stops','evga3090-six-consumer-stops','evga3090-nvidia-preflight','evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop')) {
 $baseline=Join-Path $captures 'EVGA06.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'cf7fb3897910da7f05d17cc08a70d8595de89398bea85f5e287e9e3c64c5d89f'){throw 'Expected reviewed EVGA06 baseline; preserve captures and send the error'}
}
if($manifest.Mode -in @('evga3090-four-consumer-stops','evga3090-six-consumer-stops','evga3090-nvidia-preflight','evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop')) {
 $baseline=Join-Path $captures 'EVGA07.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne '4fd72a6ad44025d31909900acde4db086ca56c7d678084df258c585936c42818'){throw 'Expected reviewed EVGA07 baseline; preserve captures and send the error'}
}
if($manifest.Mode -in @('evga3090-six-consumer-stops','evga3090-nvidia-preflight','evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop')) {
 $baseline=Join-Path $captures 'EVGA08.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'a7f683fc21550e1ebaa381119ab2feba908f37a0dbefbcc27a3f50f973d03747'){throw 'Expected reviewed EVGA08 baseline; preserve captures and send the error'}
}
if($manifest.Mode -in @('evga3090-nvidia-preflight','evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop')) {
 $baseline=Join-Path $captures 'EVGA09.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne '0385147bd6396028fb9669877b33494f42df76a31b7123ca0294515da8e2c6d1'){throw 'Expected reviewed EVGA09 baseline; preserve captures and send the error'}
}
if($manifest.Mode -in @('evga3090-nvidia-three-child-stop','evga3090-nvidia-parent-stop')) {
 $baseline=Join-Path $captures 'EVGA10.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne '16083085694eb60ee6ca2bf2522b9297b35e989efcf3582c57beccbcc51c7c83'){throw 'Expected reviewed EVGA10 baseline; preserve captures and send the error'}
}
if($manifest.Mode -eq 'evga3090-nvidia-parent-stop') {
 $baseline=Join-Path $captures 'EVGA11.TXT'
 if(!(Test-Path -LiteralPath $baseline) -or (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne '927fa507875f37b43d067fe7aa2848b0c635d8abbd9a059803371bf44cdee240'){throw 'Expected reviewed EVGA11 baseline; preserve captures and send the error'}
}
$destination=Join-Path $root 'EFI/BOOT/BOOTX64.EFI'
if(!(Test-Path -LiteralPath $destination)){throw 'Expected the existing capture EFI on this USB'}
$backup=Join-Path $root 'EFI/BOOT/BOOTX64.before-evga-text-stop.efi'
if(Test-Path -LiteralPath $backup){
 $found=$false
 for($i=1;$i -le 99;$i++){
  $candidate=Join-Path $root ('EFI/BOOT/BOOTX64.before-evga-text-stop.{0:D2}.efi' -f $i)
  if(!(Test-Path -LiteralPath $candidate)){$backup=$candidate;$found=$true;break}
 }
 if(!$found){throw 'All backup slots are occupied; preserve them and review USB state'}
}
if($PSCmdlet.ShouldProcess($destination,'Back up existing capture EFI and stage the manifest-selected EVGA text Stop experiment')) {
 Copy-Item -LiteralPath $destination -Destination $backup
 if((Get-FileHash -LiteralPath $destination).Hash -cne (Get-FileHash -LiteralPath $backup).Hash){throw 'Backup verification failed'}
 Copy-Item -LiteralPath $source -Destination $destination -Force
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash){throw 'Staged EFI hash mismatch; do not boot'}
 "Staged $destination ($hash). Previous capture EFI saved as $backup. Captures preserved. No reboot performed."
}
