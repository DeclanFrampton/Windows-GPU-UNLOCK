# Exact-machine attended graph tests. No automatic boot, format or retry.
[CmdletBinding()]
param([ValidatePattern('^[D-Zd-z]$')][string]$Drive, [switch]$Collect,
      [ValidateSet('issue33','issue109','issue31','issue180','issue19')][string]$Machine='issue33',
      [string]$Clang='clang', [string]$LldLink='lld-link', [string]$Python='python')
$ErrorActionPreference='Stop'
function Get-GraphHash([string]$Path) {
 $h=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($Path)
 try {([BitConverter]::ToString($h.ComputeHash($f))).Replace('-','').ToLowerInvariant()}
 finally {$f.Dispose();$h.Dispose()}
}
function Assert-GraphMachine([string]$Id,$Board,$Bios,$Cpu,$Video) {
 $pins=@{
  issue33=@{Board='X99-PRO/USB 3.1';Maker='^ASUSTeK';Bios='4101';Cpu='\bi7-5820K\b';Pci='2204';Subsys='87AF1043'}
  issue109=@{Board='B560M DS3H V2';Maker='^Gigabyte';Bios='F7 RB';Cpu='\bi5-11400F\b';Pci='2487';Subsys='40721458'}
  issue31=@{Board='PRIME X570-PRO';Maker='^ASUSTeK';Bios='5013';Cpu='\b5950X\b';Pci='2204';Subsys='147D10DE'}
  issue180=@{Board='B550 AORUS ELITE V2';Maker='^Gigabyte';Bios='F19';Cpu='\b5600G\b';Pci='2489';Subsys='153C10DE';Other='^PCI\\VEN_1002&DEV_1638&SUBSYS_D0001458(?:&|\\|$)'}
  issue19=@{Board='1052';Maker='^LENOVO$';Bios='S0AKT48A';Cpu='\bi9-11900K\b';Pci='2504';Subsys='881D1043'}
 }
 if(!$pins.ContainsKey($Id)){throw 'Unknown graph test machine.'};$p=$pins[$Id]
 # Known software-enumerated adapters do not establish firmware ownership.
 # Keep every PCI adapter and reject absent/unrecognized identity formats.
 $pciVideo=@($Video | Where-Object {$_.PNPDeviceID -match '^PCI\\'})
 if(@($Video | Where-Object {$_.PNPDeviceID -notmatch '^(PCI|ROOT|SWD)\\'}).Count){throw 'Ambiguous display inventory; stop and report.'}
 $identity='^PCI\\VEN_10DE&DEV_'+$p.Pci+'&SUBSYS_'+$p.Subsys+'(?:&|\\|$)'
 $target=@($pciVideo | Where-Object {$_.PNPDeviceID -match $identity})
 $displayOk=$pciVideo.Count -eq 1 -and $target.Count -eq 1
 if($p.ContainsKey('Other')) {
  $displayOk=$pciVideo.Count -eq 2 -and $target.Count -eq 1 -and
             @($pciVideo | Where-Object {$_.PNPDeviceID -match $p.Other}).Count -eq 1
 }
 if(@($Board).Count -ne 1 -or $Board.Product.Trim() -cne $p.Board -or
    $Board.Manufacturer -notmatch $p.Maker -or @($Bios).Count -ne 1 -or
    $Bios.SMBIOSBIOSVersion.Trim() -cne $p.Bios -or @($Cpu).Count -ne 1 -or
    $Cpu.Name -notmatch $p.Cpu -or !$displayOk) {
  throw "Machine does not match $Id's exact board/BIOS/CPU/display-adapter pins. Stop and report the mismatch."
 }
}
function Assert-X99GraphMachine($Board,$Bios,$Cpu,$Video){Assert-GraphMachine 'issue33' $Board $Bios $Cpu $Video}
function Assert-GraphUsb($Partition,$Disk,$Volume,[switch]$CollectOnly) {
 if(@($Partition).Count -ne 1 -or @($Disk).Count -ne 1 -or @($Volume).Count -ne 1 -or
    $Disk.BusType -ne 'USB' -or $Volume.FileSystem -ne 'FAT32' -or
    $Partition.IsSystem -or $Partition.IsBoot -or $Disk.IsBoot -or $Disk.IsSystem -or
    $Disk.IsOffline -or !$Disk.UniqueId -or
    (!$CollectOnly -and ($Disk.IsReadOnly -or $Volume.SizeRemaining -lt 16MB))) {throw 'Preparation needs a writable FAT32 USB data stick with at least 16 MB free; collection only reads it. No formatting is performed.'}
}
function Copy-GraphBoot([string]$Root,[string]$Image,[string]$ExpectedHash,[string]$MachineId='issue33') {
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
 [ordered]@{Mode='machine-graph-only';Machine=$MachineId;EfiSha256=$ExpectedHash;PreviousBootSha256=$oldHash}
}
# Dot sourcing exposes only the pure validation/staging functions to host tests.
if($MyInvocation.InvocationName -eq '.'){return}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(!$Drive){$Drive=Read-Host 'FAT32 USB drive letter (for example D)'}
if($Drive -notmatch '^[D-Zd-z]$'){throw 'Enter one drive letter from D through Z.'}
$part=Get-Partition -DriveLetter $Drive
$disk=Get-Disk -Number $part.DiskNumber
$volume=Get-Volume -DriveLetter $Drive
Assert-GraphUsb $part $disk $volume -CollectOnly:$Collect
$usb=$Drive.ToUpperInvariant()+':\'
if($Collect){
 $documents=[Environment]::GetFolderPath('MyDocuments')
 if(!$documents){throw 'Documents folder is unavailable.'}
 $output=Join-Path $documents ('GPU-Unlock-Graph-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $output | Out-Null
 & $Python -I (Join-Path $PSScriptRoot 'summarize-graph.py') (Join-Path $usb 'RTX3090-UNLOCK') (Join-Path $output 'graph-summary.json')
 if($LASTEXITCODE -ne 0){throw 'Collection summary failed. Keep the USB unchanged and report the short error.'}
 Write-Host ('Return graph-summary.json from '+$output+' and say whether Windows started directly or needed manual recovery.')
 exit 0
}
Assert-GraphMachine $Machine (Get-CimInstance Win32_BaseBoard) (Get-CimInstance Win32_BIOS) (Get-CimInstance Win32_Processor) @(Get-CimInstance Win32_VideoController)
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
$receipt=Copy-GraphBoot $usb (Join-Path $built 'GRAPH-ONLY.EFI') $manifest.EfiSha256 $Machine
$receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $usb 'RTX3090-UNLOCK/graph-stage.json') -Encoding utf8
Write-Host 'READY: fully shut down, then manually select this USB once from the firmware boot menu. No keys are required in the test.'
Write-Host 'If Windows has not started after two minutes, power off, remove the USB and use normal Windows Boot Manager. Do not repeat this run.'
Write-Host 'After Windows returns, run this same script with -Collect and the same USB drive letter. Keep raw DIAG logs local.'
