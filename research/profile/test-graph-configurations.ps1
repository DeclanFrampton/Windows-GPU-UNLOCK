# Pure configuration/inventory mocks; no hardware or disk staging.
[CmdletBinding()]
param([switch]$Report)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'prepare-graph.ps1')
function Reject([scriptblock]$Action){$failed=$false;try{& $Action}catch{$failed=$true};if(!$failed){throw 'Expected refusal.'}}
foreach($file in Get-ChildItem (Join-Path $PSScriptRoot 'graph-configurations') -Filter '*.json') {
 $p=Read-GraphConfiguration $file.BaseName
 $board=[pscustomobject]@{Manufacturer=$p.ManufacturerPrefix;Product=$p.Board}
 $bios=[pscustomobject]@{SMBIOSBIOSVersion=$p.Bios};$cpu=[pscustomobject]@{Name=$p.CpuToken}
 $video=@($p.Adapters|ForEach-Object{[pscustomobject]@{PNPDeviceID=('PCI\VEN_'+$_.Vendor+'&DEV_'+$_.Device+'&SUBSYS_'+$_.Subsystem+'\PRIVATE')}})
 $drivers=@()
 foreach($a in @($p.KnownNonPciAdapters | Where-Object {$_})){
  $id=$a.Enumerator+'\PRIVATE';$video += [pscustomobject]@{PNPDeviceID=$id}
  $drivers += [pscustomobject]@{DeviceID=$id;DriverProviderName=$a.Provider;DriverVersion=$a.Version;IsSigned=$true}
 }
 Assert-GraphMachine $p.Id $board $bios $cpu $video $drivers
 $oldManufacturer=$board.Manufacturer;$board.Manufacturer='OTHER';Reject {Assert-GraphMachine $p.Id $board $bios $cpu $video $drivers};$board.Manufacturer=$oldManufacturer
 $oldBoard=$board.Product;$board.Product+='other';Reject {Assert-GraphMachine $p.Id $board $bios $cpu $video $drivers};$board.Product=$oldBoard
 $oldCpu=$cpu.Name;$cpu.Name='OTHER';Reject {Assert-GraphMachine $p.Id $board $bios $cpu $video $drivers};$cpu.Name=$oldCpu
 Reject {Assert-GraphMachine $p.Id $board $bios $cpu @() $drivers}
 $bios.SMBIOSBIOSVersion+='other';Reject {Assert-GraphMachine $p.Id $board $bios $cpu $video $drivers};$bios.SMBIOSBIOSVersion=$p.Bios
 Reject {Assert-GraphMachine $p.Id $board $bios $cpu @($video+$video) $drivers}
 Reject {Assert-GraphMachine $p.Id $board $bios $cpu @($video+[pscustomobject]@{PNPDeviceID='USB\PRIVATE'}) $drivers}
}
Reject {Read-GraphConfiguration '../issue33'}
Reject {Read-GraphConfiguration 'missing'}
# Issue151: preserve both physical GPUs and refuse every unknown software
# adapter independently, even when its marketing name/version are known.
$case151=Read-GraphConfiguration 'issue151'
$board151=[pscustomobject]@{Manufacturer='Gigabyte Technology Co., Ltd.';Product=$case151.Board}
$bios151=[pscustomobject]@{SMBIOSBIOSVersion='F40'}
$cpu151=[pscustomobject]@{Name='AMD Ryzen 7 5800X 8-Core Processor'}
$pci151=@($case151.Adapters|ForEach-Object{[pscustomobject]@{PNPDeviceID=('PCI\VEN_'+$_.Vendor+'&DEV_'+$_.Device+'&SUBSYS_'+$_.Subsystem+'\PRIVATE')}})
Assert-GraphMachine 'issue151' $board151 $bios151 $cpu151 $pci151
foreach($name in @('Virtual Desktop Monitor','SudoMaker Virtual Display Adapter','Meta Virtual Monitor','vorpX Virtual Display')){
 $unknown=[pscustomobject]@{Name=$name;PNPDeviceID=$null}
 Reject {Assert-GraphMachine 'issue151' $board151 $bios151 $cpu151 @($pci151+$unknown)}
}
foreach($enumerator in @('ROOT','SWD')){
 $unknown=[pscustomobject]@{PNPDeviceID=($enumerator+'\PRIVATE')}
 Reject {Assert-GraphMachine 'issue151' $board151 $bios151 $cpu151 @($pci151+$unknown)}
}
Reject {Assert-GraphMachine 'issue151' $board151 $bios151 $cpu151 @($pci151[0])}
$wrong151=@($pci151|ForEach-Object{[pscustomobject]@{PNPDeviceID=$_.PNPDeviceID.Replace('403F1458','48973842')}})
Reject {Assert-GraphMachine 'issue151' $board151 $bios151 $cpu151 $wrong151}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('graph-config-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
$good=Get-Content (Join-Path $PSScriptRoot 'graph-configurations/issue33.json') -Raw
foreach($bad in @(
 $good.Replace('graph-only','unlock'),
 $good.Replace('"SchemaVersion": 1','"SchemaVersion": 2'),
 $good.Replace('"2204"','".*"'),
 $good.Replace('"Board":','"Unexpected": 1, "Board":'),
 $good.Replace('"Adapters": [','"Adapters": null, "extra": ['),
 $good.Replace('"Id": "issue33"','"Id": "other"')
)) {
 [IO.File]::WriteAllText((Join-Path $temp 'issue33.json'),$bad)
 Reject {Read-GraphConfiguration 'issue33' $temp}
}
$known=Get-Content (Join-Path $PSScriptRoot 'graph-configurations/issue31.json') -Raw
foreach($bad in @($known.Replace('"LCI"','"PCI"'),$known.Replace('"LuminonCore"','".*"'),$known.Replace('"1.0.2018.1204"','"*"'))){
 [IO.File]::WriteAllText((Join-Path $temp 'issue31.json'),$bad)
 Reject {Read-GraphConfiguration 'issue31' $temp}
}
# Legacy dot-source entry point must expose functions without executing a run.
. (Join-Path $PSScriptRoot 'prepare-x99-graph.ps1')
if((Read-GraphConfiguration 'issue33').Scope -cne 'graph-only'){throw 'Legacy entry point failed'}
Write-Host 'PASS: all configuration fixtures, mismatched BIOS/adapters, unknown inventory, traversal, malformed schema/scope/IDs, legacy entry point.'
if($Report){
 $docs=[Environment]::GetFolderPath('MyDocuments');if(!$docs){throw 'Documents unavailable.'}
 $folder=Join-Path $docs ('GPU-Unlock-Graph-Config-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $folder|Out-Null
 $summary=[ordered]@{Test='graph-configuration-v2';Passed=$true;Case='151';FixtureOnly=$true;PhysicalAdapterPins=2;UnknownDisplayCasesRefused=6;MissingDisplayRefused=$true;Other2216SubsystemRefused=$true;HardwareInventoryRead=$false;HardwareUnlockTested=$false;VirtualAdapterAdmissionGranted=$false;WriteEligible=$false}
 $path=Join-Path $folder 'graph-configuration.json'
 $summary|ConvertTo-Json|Set-Content -LiteralPath $path -Encoding UTF8
 Write-Host ('Return only '+$path+'. This tests fixtures, not your hardware. No EFI, settings changes or reboot.')
}
