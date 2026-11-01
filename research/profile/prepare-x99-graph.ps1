# One attended graph test for issue 33. No automatic boot, format or retry.
[CmdletBinding()]
param([ValidatePattern('^[D-Zd-z]$')][string]$Drive, [switch]$Collect,
      [string]$Clang='clang', [string]$LldLink='lld-link', [string]$Python='python')
$ErrorActionPreference='Stop'
function Get-GraphHash([string]$Path) {
 $h=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($Path)
 try {([BitConverter]::ToString($h.ComputeHash($f))).Replace('-','').ToLowerInvariant()}
 finally {$f.Dispose();$h.Dispose()}
}
function Assert-X99GraphMachine($Board,$Bios,$Cpu,$Video) {
 if(@($Board).Count -ne 1 -or $Board.Product.Trim() -cne 'X99-PRO/USB 3.1' -or
    $Board.Manufacturer -notmatch '^ASUSTeK' -or @($Bios).Count -ne 1 -or
    $Bios.SMBIOSBIOSVersion.Trim() -cne '4101' -or @($Cpu).Count -ne 1 -or
    $Cpu.Name -notmatch '\bi7-5820K\b' -or @($Video).Count -ne 1 -or
    $Video.PNPDeviceID -notmatch '^PCI\\VEN_10DE&DEV_2204&SUBSYS_87AF1043(?:&|\\|$)') {
  throw 'This test is only for issue 33: X99-PRO/USB 3.1 BIOS 4101, i7-5820K, sole ASUS 2204/1043:87af GPU. Stop and report the mismatch.'
 }
}
function Assert-GraphUsb($Partition,$Disk,$Volume) {
 if(@($Partition).Count -ne 1 -or @($Disk).Count -ne 1 -or @($Volume).Count -ne 1 -or
    $Disk.BusType -ne 'USB' -or $Volume.FileSystem -ne 'FAT32' -or
    $Partition.IsSystem -or $Partition.IsBoot -or $Disk.IsBoot -or $Disk.IsSystem -or
    $Disk.IsReadOnly -or $Disk.IsOffline -or !$Disk.UniqueId -or
    $Volume.SizeRemaining -lt 16MB) {throw 'Select an existing writable FAT32 USB data stick with at least 16 MB free. No formatting is performed.'}
}
function Copy-GraphBoot([string]$Root,[string]$Image,[string]$ExpectedHash) {
 if((Get-GraphHash $Image) -cne $ExpectedHash){throw 'Built EFI hash mismatch.'}
 $capture=Join-Path $Root 'RTX3090-UNLOCK'
 if((Test-Path -LiteralPath $capture) -and @(Get-ChildItem -LiteralPath $capture -Force).Count){throw 'Capture folder is not empty. Preserve it; do not mix or repeat tests.'}
 $boot=Join-Path $Root 'EFI/BOOT/BOOTX64.EFI';$temp=Join-Path $Root 'EFI/BOOT/GRAPH-NEW.EFI'
 if(Test-Path -LiteralPath $temp){throw 'A previous staging file exists. Stop; no automatic retry.'}
 $oldHash=$null;$backup=$null
 if(Test-Path -LiteralPath $boot){
  $oldHash=Get-GraphHash $boot
  $backup=Join-Path $Root ('EFI/BOOT/BEFORE-GRAPH-'+$oldHash+'.EFI')
  if(!(Test-Path -LiteralPath $backup)){Copy-Item -LiteralPath $boot -Destination $backup}
  if((Get-GraphHash $backup) -cne $oldHash){throw 'Previous boot loader backup verification failed.'}
 }
 New-Item -ItemType Directory -Path (Split-Path $boot),$capture -Force | Out-Null
 Copy-Item -LiteralPath $Image -Destination $temp
 if((Get-GraphHash $temp) -cne $ExpectedHash){throw 'Staged EFI readback failed; original boot file is retained.'}
 if($oldHash -and (Get-GraphHash $boot) -cne $oldHash){throw 'Existing USB boot file changed; stop.'}
 Move-Item -LiteralPath $temp -Destination $boot -Force
 if((Get-GraphHash $boot) -cne $ExpectedHash){throw 'Final USB readback failed. Do not boot.'}
 [ordered]@{Mode='issue33-graph-only';EfiSha256=$ExpectedHash;PreviousBootSha256=$oldHash}
}
# Dot sourcing exposes only the pure validation/staging functions to host tests.
if($MyInvocation.InvocationName -eq '.'){return}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(!$Drive){$Drive=Read-Host 'FAT32 USB drive letter (for example D)'}
if($Drive -notmatch '^[D-Zd-z]$'){throw 'Enter one drive letter from D through Z.'}
$part=Get-Partition -DriveLetter $Drive
$disk=Get-Disk -Number $part.DiskNumber
$volume=Get-Volume -DriveLetter $Drive
Assert-GraphUsb $part $disk $volume
$usb=$Drive.ToUpperInvariant()+':\'
if($Collect){
 $documents=[Environment]::GetFolderPath('MyDocuments')
 if(!$documents){throw 'Documents folder is unavailable.'}
 $output=Join-Path $documents ('GPU-Unlock-X99-Graph-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $output | Out-Null
 & $Python -I (Join-Path $PSScriptRoot 'summarize-graph.py') (Join-Path $usb 'RTX3090-UNLOCK') (Join-Path $output 'graph-summary.json')
 if($LASTEXITCODE -ne 0){throw 'Collection summary failed. Keep the USB unchanged and report the short error.'}
 Write-Host ('Return graph-summary.json from '+$output+' and say whether Windows started directly or needed manual recovery.')
 exit 0
}
Assert-X99GraphMachine (Get-CimInstance Win32_BaseBoard) (Get-CimInstance Win32_BIOS) (Get-CimInstance Win32_Processor) @(Get-CimInstance Win32_VideoController)
try {$secure=Confirm-SecureBootUEFI} catch {throw 'Secure Boot state could not be verified. Stop and report; do not change settings.'}
if($secure -ne $false){throw 'Secure Boot must already be off for this unsigned test. Do not change it for this script.'}
$windows=@(Get-Partition | Where-Object {$_.IsSystem -and $_.Guid})
if($windows.Count -ne 1 -or $windows[0].DiskNumber -eq $part.DiskNumber){throw 'Cannot uniquely pin the current internal Windows ESP.'}
Write-Host 'ONE attended EFI graph test: firmware protocol/GOP metadata and PCI-header reads, USB log, then attempted Windows boot.'
Write-Host 'No GPU MMIO/PROM, driver release, unlock or firmware-variable writes. Firmware/display/input may hang; Windows may fail to start.'
Write-Host 'Recovery is unproven: power off, remove this USB, and choose your normal Windows Boot Manager. No automatic retry or rollback.'
if((Read-Host 'If you accept this boundary, type PREPARE (anything else stops)') -cne 'PREPARE'){throw 'Stopped without staging.'}
& (Join-Path $PSScriptRoot 'build-graph-only.ps1') -WindowsEspGuid ([guid]$windows[0].Guid) -Clang $Clang -LldLink $LldLink -Python $Python
if(!$?){throw 'Graph build failed; do not boot.'}
$built=Join-Path $repo 'internal-boot/boot/build/graph-only'
$manifest=Get-Content -LiteralPath (Join-Path $built 'manifest.json') -Raw | ConvertFrom-Json
if($manifest.FixtureOnly -ne $false -or $manifest.Mode -cne 'graph-only-build' -or
   $manifest.CanUnlock -ne $false -or $manifest.CanDetach -ne $false -or $manifest.ReadsGpuMmio -ne $false){throw 'Unexpected graph build manifest.'}
# Recheck the target after compilation before any USB write.
$fresh=Get-Partition -DriveLetter $Drive
$freshDisk=Get-Disk -Number $fresh.DiskNumber
Assert-GraphUsb $fresh $freshDisk (Get-Volume -DriveLetter $Drive)
if($fresh.DiskNumber -ne $part.DiskNumber -or $fresh.Offset -ne $part.Offset -or $fresh.Size -ne $part.Size -or
   $freshDisk.UniqueId -cne $disk.UniqueId){throw 'USB partition changed; do not stage.'}
$receipt=Copy-GraphBoot $usb (Join-Path $built 'GRAPH-ONLY.EFI') $manifest.EfiSha256
$receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $usb 'RTX3090-UNLOCK/graph-stage.json') -Encoding utf8
Write-Host 'READY: fully shut down, then manually select this USB once from the firmware boot menu. No keys are required in the test.'
Write-Host 'If Windows has not started after two minutes, power off, remove the USB and use normal Windows Boot Manager. Do not repeat this run.'
Write-Host 'After Windows returns, run this same script with -Collect and the same USB drive letter. Keep raw DIAG logs local.'
