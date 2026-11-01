# Issue114 only. Prepare one attended generic probe; never unlock or reboot.
[CmdletBinding()]
param([ValidatePattern('^[D-Zd-z]$')][string]$Drive,[switch]$Collect,
 [string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python')
$ErrorActionPreference='Stop'
function ProbeHash([string]$Path){
 $sha=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($Path)
 try {([BitConverter]::ToString($sha.ComputeHash($f))).Replace('-','').ToLowerInvariant()}
 finally {$f.Dispose();$sha.Dispose()}
}
function Assert-Zotac114($Board,$Bios,$Cpu,$Video){
 $pci=@($Video | Where-Object {$_.PNPDeviceID -match '^PCI\\'})
 $target=@($pci | Where-Object {$_.PNPDeviceID -match '^PCI\\VEN_10DE&DEV_2504&SUBSYS_263019DA(?:&|\\|$)'})
 $amd=@($pci | Where-Object {$_.PNPDeviceID -match '^PCI\\VEN_1002&DEV_[0-9A-F]{4}&SUBSYS_[0-9A-F]{8}(?:&|\\|$)'})
 if(@($Board).Count -ne 1 -or $Board.Manufacturer -notmatch '^Gigabyte' -or
    $Board.Product.Trim() -cne 'B650M DS3H' -or @($Bios).Count -ne 1 -or
    $Bios.SMBIOSBIOSVersion.Trim() -cne 'F21' -or @($Cpu).Count -ne 1 -or
    $Cpu.Name -notmatch '\bRyzen 5 7600\b' -or $pci.Count -ne 2 -or $target.Count -ne 1 -or $amd.Count -ne 1 -or
    @($Video | Where-Object {$_.PNPDeviceID -notmatch '^(PCI|ROOT|SWD)\\'}).Count){
  throw 'Not issue114: expected B650M DS3H/F21/Ryzen7600, Zotac2504/19da:2630 and one AMD PCI companion. Stop; do not change settings.'
 }
}
function Assert-ProbeUsb($Part,$Disk,$Volume,[switch]$ReadOnly){
 if(@($Part).Count -ne 1 -or @($Disk).Count -ne 1 -or @($Volume).Count -ne 1 -or
    $Disk.BusType -ne 'USB' -or $Volume.FileSystem -ne 'FAT32' -or $Part.IsSystem -or $Part.IsBoot -or
    $Disk.IsBoot -or $Disk.IsSystem -or $Disk.IsOffline -or !$Disk.UniqueId -or
    (!$ReadOnly -and ($Disk.IsReadOnly -or $Volume.SizeRemaining -lt 256MB))){throw 'Need a FAT32 USB data stick, 256 MB free for preparation. No format is performed.'}
}
function Archive-ProbeCaptures([string]$Root){
 $rootPath=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
 $folder=[IO.Path]::GetFullPath((Join-Path $Root 'RTX3090-UNLOCK'))
 if(!$folder.StartsWith($rootPath,[StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($folder) -cne 'RTX3090-UNLOCK'){throw 'Invalid archive boundary.'}
 if(Test-Path -LiteralPath $folder){
  $name='RTX3090-UNLOCK.before-probe-'+[guid]::NewGuid().ToString('N')
  $archive=[IO.Path]::GetFullPath((Join-Path $Root $name))
  if(!$archive.StartsWith($rootPath,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $archive)){throw 'Invalid archive destination.'}
  Rename-Item -LiteralPath $folder -NewName $name
  if((Test-Path -LiteralPath $folder) -or !(Test-Path -LiteralPath $archive)){throw 'Archive rename failed. Do not boot.'}
 }
 New-Item -ItemType Directory -Path $folder -Force | Out-Null
}
function Stage-Probe([string]$Root,[string]$Image,[string]$Hash){
 if((ProbeHash $Image) -cne $Hash){throw 'Built image hash mismatch.'}
 if(Test-Path -LiteralPath (Join-Path $Root 'RTX3090-UNLOCK/probe114-stage.json')){throw 'This attended run is already staged. Collect/review its files; do not restage or repeat automatically.'}
 $boot=Join-Path $Root 'EFI/BOOT/BOOTX64.EFI';$temp=Join-Path $Root 'EFI/BOOT/PROBE-NEW.EFI'
 if(Test-Path -LiteralPath $temp){throw 'Partial staging exists; stop rather than retry.'}
 $old=$null
 if(Test-Path -LiteralPath $boot){
  $old=ProbeHash $boot;$backup=Join-Path $Root ('EFI/BOOT/BEFORE-PROBE-'+$old+'.EFI')
  if(!(Test-Path -LiteralPath $backup)){Copy-Item -LiteralPath $boot -Destination $backup}
  if((ProbeHash $backup) -cne $old){throw 'Original boot loader backup failed verification.'}
 }
 Archive-ProbeCaptures $Root
 New-Item -ItemType Directory -Path (Split-Path $boot) -Force | Out-Null
 Copy-Item -LiteralPath $Image -Destination $temp
 if((ProbeHash $temp) -cne $Hash){throw 'Copy readback failed; old boot loader retained.'}
 if($old -and (ProbeHash $boot) -cne $old){throw 'USB boot file changed; stop.'}
 Move-Item -LiteralPath $temp -Destination $boot -Force
 if((ProbeHash $boot) -cne $Hash){throw 'Final copy verification failed. Do not boot.'}
 [IO.File]::WriteAllText((Join-Path $Root 'RTX3090-UNLOCK/probe114-stage.json'),
  (@{Mode='issue114-read-only-probe';EfiSha256=$Hash} | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
}
function Export-ProbeReport([string]$Repo,[string]$Folder,[string]$Output,[string]$Python){
 $p=New-Object System.Diagnostics.Process
 try {
  $command=Get-Command $Python -CommandType Application -ErrorAction Stop
  $p.StartInfo.FileName=$command.Source
  $p.StartInfo.Arguments='-I research/profile/check-compatibility.py "'+(Join-Path $folder '.')+'" --json'
  $p.StartInfo.WorkingDirectory=$repo;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
  $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
  $p.StartInfo.StandardOutputEncoding=New-Object System.Text.UTF8Encoding($false)
  $p.Start() | Out-Null;$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
  if(!$p.WaitForExit(120000)){$p.Kill();throw 'Offline report timed out.'}
  if($p.ExitCode -notin @(0,2,3)){throw 'Offline report failed; keep original USB files local.'}
  $report=$stdout.Result | ConvertFrom-Json
  if($report.write_eligible -ne $false -or $report.hardware_tested -ne $false -or $report.route -cne 'automatic_local_profile'){throw 'Unexpected report.'}
  $report.next_step='Await review of this attended capture. Do not repeat the boot, generate a profile or stage unlock yet.'
  $paths=@(Get-ChildItem -LiteralPath $folder -Filter 'DIAG??.TXT' -File | Where-Object {$_.Name -match '^DIAG[0-9]{2}\.TXT$'})
  if($paths.Count -gt 4){throw 'Too many captures for this one-run review; preserve them and stop.'}
  $markers=@($paths | ForEach-Object {
   if($_.Length -gt 8MB){throw 'Capture exceeds the summary limit.'}
   $text=[IO.File]::ReadAllText($_.FullName)
   [ordered]@{Capture=$_.Name;Sha256=(ProbeHash $_.FullName)
    CompleteMarkers=@([regex]::Matches($text,'(?m)^capture-complete=([01])\r?$') | ForEach-Object {$_.Groups[1].Value})
    EnvelopeRefusalRecorded=$text.Contains('incomplete reason=probe-unreviewed-envelope status=0x8000000000000003')
    FailedMmioReads=@([regex]::Matches($text,'(?m)^mmio off=0x[0-9a-f]{8} status=(0x[0-9a-f]{16}) value=0x[0-9a-f]{8}\r?$') | Where-Object {$_.Groups[1].Value -cne '0x0000000000000000'}).Count}
  })
  $public=[ordered]@{Test='issue114-pinned-probe-review';HardwareVerified=$false;WriteEligible=$false;Compatibility=$report;CaptureMarkers=$markers}
  [IO.File]::WriteAllText((Join-Path $output 'report.json'),($public | ConvertTo-Json -Depth 18),[Text.UTF8Encoding]::new($false))
 } finally {$p.Dispose()}
}
if($MyInvocation.InvocationName -eq '.'){return}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(!$Drive){$Drive=Read-Host 'FAT32 USB drive letter'}
if($Drive -notmatch '^[D-Zd-z]$'){throw 'Enter one drive letter D through Z.'}
$part=Get-Partition -DriveLetter $Drive;$disk=Get-Disk -Number $part.DiskNumber;$volume=Get-Volume -DriveLetter $Drive
Assert-ProbeUsb $part $disk $volume -ReadOnly:$Collect
$usb=$Drive.ToUpperInvariant()+':\'
if($Collect){
 $folder=Join-Path $usb 'RTX3090-UNLOCK';$documents=[Environment]::GetFolderPath('MyDocuments')
 if(!$documents){throw 'Documents folder unavailable.'}
 $output=Join-Path $documents ('GPU-Unlock-Zotac-Capture-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $output | Out-Null
 Export-ProbeReport $repo $folder $output $Python
 Write-Host ('Return reviewed report.json from '+$output+' and say whether Windows started directly or manual recovery was needed. Keep all PROM/IMG/DIAG files local.')
 exit 0
}
Assert-Zotac114 (Get-CimInstance Win32_BaseBoard) (Get-CimInstance Win32_BIOS) (Get-CimInstance Win32_Processor) @(Get-CimInstance Win32_VideoController)
try {$secure=Confirm-SecureBootUEFI}catch{throw 'Secure Boot state cannot be verified. Stop; do not change settings.'}
if($secure -ne $false){throw 'Secure Boot must already be off. Do not change it for this test.'}
$windows=@(Get-Partition | Where-Object {$_.IsSystem -and $_.Guid})
if($windows.Count -ne 1 -or $windows[0].DiskNumber -eq $part.DiskNumber){throw 'Cannot uniquely pin current internal Windows ESP.'}
Write-Host 'NEW boundary: PCI resource/attribute/parent reads, 16 fixed target BAR0 DWORDs and full 1 MiB PROM (up to 262160 direct MMIO reads), plus loaded firmware-driver image copies from CPU memory.'
Write-Host 'No GPU/PCI writes, driver detach, reset, GPU firmware execution/upload or unlock. Reads may have side effects; display/input/firmware or Windows may hang. Recovery is unproven.'
Write-Host 'Manual power-off/USB removal and normal Windows Boot Manager may be needed. No automatic retry or rollback. Existing USB captures are renamed to a preserved archive.'
if((Read-Host 'Accept ONE attended capture? Type ACCEPT-MMIO to prepare; anything else stops') -cne 'ACCEPT-MMIO'){throw 'Stopped without staging.'}
& (Join-Path $PSScriptRoot 'build-probe.ps1') -WindowsEspGuid ([guid]$windows[0].Guid) -TargetBus 1 -ExpectedDevice '250410de' -ExpectedSubsystem '263019da' -Clang $Clang -LldLink $LldLink -Python $Python
if(!$?){throw 'Probe build failed.'}
. (Join-Path $PSScriptRoot 'probe-manifest.ps1')
$built=Join-Path $repo 'internal-boot/boot/build/probe-generic';$image=Join-Path $built 'BOOTX64.EFI'
$manifest=Get-Content -LiteralPath (Join-Path $built 'manifest.json') -Raw | ConvertFrom-Json
Assert-GuGenericProbeManifest $repo $manifest $image
if($manifest.ExpectedDevice -cne '250410de' -or $manifest.ExpectedSubsystem -cne '263019da' -or $manifest.ExpectedSegment -ne 0 -or $manifest.TargetBus -ne 1){throw 'Probe pins do not match issue114.'}
$pe=Get-Content -LiteralPath (Join-Path $built 'pe-verification.json') -Raw | ConvertFrom-Json
if($pe.machine -cne 'AMD64' -or $pe.subsystem -ne 10 -or $pe.imports -ne 0 -or $pe.sha256 -cne $manifest.EfiSha256){throw 'Missing or mismatched PE verification.'}
$fresh=Get-Partition -DriveLetter $Drive;$freshDisk=Get-Disk -Number $fresh.DiskNumber
Assert-ProbeUsb $fresh $freshDisk (Get-Volume -DriveLetter $Drive)
if($freshDisk.UniqueId -cne $disk.UniqueId -or $fresh.DiskNumber -ne $part.DiskNumber -or $fresh.Offset -ne $part.Offset -or $fresh.Size -ne $part.Size){throw 'USB identity changed; stop.'}
Stage-Probe $usb $image $manifest.EfiSha256
Write-Host 'READY. Fully shut down and manually select this USB once. No Shift keys. Expect capture then Windows.'
Write-Host 'If Windows has not started within two minutes, power off, remove USB and use normal Windows Boot Manager. Do not repeat.'
Write-Host 'In Windows run this same script with -Collect. Return only report.json and the Windows outcome; remove USB afterward.'
