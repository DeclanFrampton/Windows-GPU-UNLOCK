# Read Windows PnP parent associations; no PCI config, MMIO or device changes.
[CmdletBinding()]
param([switch]$SelfTest)
$ErrorActionPreference='Stop'
function Get-PciParentChain([string]$Start,[scriptblock]$ReadParent){
 $rows=@();$seen=@{};$current=$Start;$state='hop-limit'
 for($hop=0;$hop -lt 16;$hop++){
  if(!$current -or $current.Length -gt 2048){$state='unknown';break}
  if($seen.ContainsKey($current)){$state='cycle';break}
  $seen[$current]=$true
  $pci=$null
  if($current -match '^PCI\\VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})(?:&SUBSYS_([0-9A-F]{8}))?(?:&|\\|$)'){
   $pci=[ordered]@{Vendor=$Matches[1];Device=$Matches[2];Subsystem=$Matches[3]}
  }
  $rows+= [pscustomobject]@{Hop=$hop;Pci=$pci}
  try{$parent=@(& $ReadParent $current)}catch{$state='unavailable';break}
  if($parent.Count -ne 1 -or $parent[0] -isnot [string] -or $parent[0].Length -gt 2048){$state='unknown';break}
  if($parent[0] -ceq ''){$state='root-reported';break}
  $current=$parent[0]
 }
 return [ordered]@{State=$state;Nodes=$rows}
}
if($SelfTest){
 $target='PCI\VEN_10DE&DEV_2208&SUBSYS_40811458\PRIVATE'
 $bridge='PCI\VEN_1022&DEV_14EE\PRIVATE'
 $r=Get-PciParentChain $target {param($id) if($id -eq $target){$bridge}else{''}}
 if($r.State -cne 'root-reported' -or $r.Nodes.Count -ne 2 -or $r.Nodes[0].Pci.Subsystem -cne '40811458' -or $r.Nodes[1].Pci.Vendor -cne '1022'){throw 'Parent chain regression.'}
 if(($r|ConvertTo-Json -Depth 8) -match 'PRIVATE|PCI\\'){throw 'Raw identity leaked.'}
 if((Get-PciParentChain $target {param($id) $id}).State -cne 'cycle'){throw 'Cycle regression.'}
 if((Get-PciParentChain $target {throw 'PRIVATE'}).State -cne 'unavailable'){throw 'Read failure regression.'}
 if((Get-PciParentChain $target {'A';'B'}).State -cne 'unknown'){throw 'Ambiguous parent regression.'}
 $script:sequence=0
 if((Get-PciParentChain $target {$script:sequence++;'NODE'+$script:sequence}).State -cne 'hop-limit'){throw 'Hop limit regression.'}
 if((Get-PciParentChain ('X'*2049) {''}).State -cne 'unknown'){throw 'Bounds regression.'}
 Write-Host 'PASS: PCI parent chain, subsystem, privacy, cycle, failed/ambiguous read and bounds.'
 exit 0
}
$status='observed';$targets=@()
try{
 # Exact issue108 identity; no arbitrary device access or device enable operation.
 $devices=@(Get-PnpDevice -PresentOnly -Class Display -ErrorAction Stop | Where-Object {$_.InstanceId -match '^PCI\\VEN_10DE&DEV_2208&SUBSYS_40811458(?:&|\\)'})
 if($devices.Count -ne 1){$status='target-not-unique'}else{
  $targets+=Get-PciParentChain $devices[0].InstanceId {
   param($id)
   $p=Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Parent -ErrorAction Stop
   if($p.Type -cne 'String' -or $p.Data -isnot [string]){throw 'Unknown parent property.'}
   $p.Data
  }
 }
}catch{$status='unavailable';$targets=@()}
$report=[ordered]@{Test='windows-pci-parent-v1';ReadStatus=$status;Targets=$targets;RawIdentitiesExported=$false;ExternalConnectorVerified=$false;PrebootTopologyVerified=$false;HardwareUnlockTested=$false;WriteEligible=$false}
$docs=[Environment]::GetFolderPath('MyDocuments');if(!$docs){throw 'Documents unavailable.'}
$folder=Join-Path $docs ('GPU-Unlock-Pci-Parents-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $folder|Out-Null
$path=Join-Path $folder 'pci-parents.json'
$report|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding UTF8
Write-Host ('Return only reviewed '+$path+'. Unknown/unavailable is acceptable. No settings change, EFI or reboot.')
