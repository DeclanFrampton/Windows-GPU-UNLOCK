# Mock identity/filesystem checks only; no real firmware or device queries.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'prepare-resource-capture.ps1')
function Reject([scriptblock]$Action){$failed=$false;try{& $Action}catch{$failed=$true};if(!$failed){throw 'Expected refusal absent'}}
$p=Read-ProbeConfiguration 'issue31'
$b=[pscustomobject]@{Manufacturer='ASUSTeK COMPUTER INC.';Product='PRIME X570-PRO'}
$bios=[pscustomobject]@{SMBIOSBIOSVersion='5013'};$cpu=[pscustomobject]@{Name='AMD Ryzen 9 5950X 16-Core Processor'}
$gpu=[pscustomobject]@{PNPDeviceID='PCI\VEN_10DE&DEV_2204&SUBSYS_147D10DE&REV_A1\PRIVATE'}
$lci=[pscustomobject]@{PNPDeviceID='LCI\PRIVATE'};$root=[pscustomobject]@{PNPDeviceID='ROOT\PRIVATE'}
$driver=[pscustomobject]@{DeviceID='LCI\PRIVATE';DriverProviderName='LuminonCore';DriverVersion='1.0.2018.1204';IsSigned=$true}
Assert-PinnedProbe $p $b $bios $cpu @($gpu,$lci,$root) @($driver)
Reject {Assert-PinnedProbe $p $b $bios $cpu @($gpu,$lci,$gpu) @($driver)}
Reject {Assert-PinnedProbe $p $b $bios $cpu @($gpu) @($driver)}
Reject {Assert-PinnedProbe $p $b $bios $cpu @($gpu,$lci) @()}
$driver.IsSigned=$false;Reject {Assert-PinnedProbe $p $b $bios $cpu @($gpu,$lci) @($driver)};$driver.IsSigned=$true
$driver.DriverVersion='other';Reject {Assert-PinnedProbe $p $b $bios $cpu @($gpu,$lci) @($driver)};$driver.DriverVersion='1.0.2018.1204'
$gpu.PNPDeviceID='PCI\VEN_10DE&DEV_2204&SUBSYS_000010DE\PRIVATE';Reject {Assert-PinnedProbe $p $b $bios $cpu @($gpu,$lci) @($driver)}
Reject {Read-ProbeConfiguration '../issue31'}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('resource-prep-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
$raw=Get-Content (Join-Path $PSScriptRoot 'probe-configurations/issue31.json') -Raw
foreach($bad in @($raw.Replace('"TargetBus": 8','"TargetBus": 0'),$raw.Replace('pinned-read-only-resource-capture','unlock'),$raw.Replace('220410de','ffffffff'),$raw.Replace('"LCI"','"PCI"'))){
 [IO.File]::WriteAllText((Join-Path $temp 'issue31.json'),$bad);Reject {Read-ProbeConfiguration 'issue31' $temp}
}
$source=Join-Path $temp 'source.efi';[IO.File]::WriteAllText($source,'mock fixture')
Stage-Probe $temp $source (ProbeHash $source) 'issue31'
if(!(Test-Path -LiteralPath (Join-Path $temp 'RTX3090-UNLOCK/pinned-probe-stage.json'))){throw 'Generic stage receipt missing'}
Reject {Stage-Probe $temp $source (ProbeHash $source) 'issue31'}
Write-Host 'PASS: X570/3090/LCI pins, changed inventory/driver refusals, malformed configuration, generic stage marker and repeat refusal.'
