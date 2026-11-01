# Pure configuration/inventory mocks; no hardware or disk staging.
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
 $bios.SMBIOSBIOSVersion+='other';Reject {Assert-GraphMachine $p.Id $board $bios $cpu $video $drivers};$bios.SMBIOSBIOSVersion=$p.Bios
 Reject {Assert-GraphMachine $p.Id $board $bios $cpu @($video+$video) $drivers}
 Reject {Assert-GraphMachine $p.Id $board $bios $cpu @($video+[pscustomobject]@{PNPDeviceID='USB\PRIVATE'}) $drivers}
}
Reject {Read-GraphConfiguration '../issue33'}
Reject {Read-GraphConfiguration 'missing'}
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
