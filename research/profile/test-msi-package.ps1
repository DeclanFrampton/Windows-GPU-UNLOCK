param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'msi-package-lib.ps1')
$source=[IO.Path]::GetFullPath($PackageDirectory);$null=Assert-MsiPackage $source
$temp=Join-Path $env:TEMP ('msi-package-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($temp)
$manager=Join-Path $PSScriptRoot 'prepare-msi-install.ps1'
$state=Join-Path $temp 'state';$null=& $manager -PackageDirectory $source -StateDirectory $state
$plan=Get-Content -LiteralPath (Join-Path $state 'installation-plan.json') -Raw|ConvertFrom-Json
if($plan.Installed -or $plan.Armed -or $plan.FirmwareWritten -or $plan.AttendedRearm.Enabled -or $plan.Unattended.Enabled -or $plan.Persistence.Proven){throw 'Preparation unexpectedly enabled execution'}
function Refused([scriptblock]$Action){$blocked=$false;try{& $Action|Out-Null}catch{$blocked=$true};if(!$blocked){throw 'Expected refusal'}}
Refused {& $manager -PackageDirectory $source -StateDirectory $state}
Refused {& $manager -PackageDirectory $source -StateDirectory (Join-Path $source 'nested-state')}
foreach($mode in @('tamper','missing','automatic','duplicate')){
 $copy=Join-Path $temp $mode;Copy-Item -LiteralPath $source -Destination $copy -Recurse
 switch($mode){
  tamper {Add-Content -LiteralPath (Join-Path $copy 'README.md') 'modified'}
  missing {Remove-Item -LiteralPath (Join-Path $copy 'UNLOCK.EFI')}
  automatic {$p=Join-Path $copy 'package.json';$m=Get-Content $p -Raw|ConvertFrom-Json;$m.AutomaticUnlock=$true;$m|ConvertTo-Json -Depth 8|Set-Content $p}
  duplicate {$p=Join-Path $copy 'package.json';$m=Get-Content $p -Raw|ConvertFrom-Json;$m.Files[0].Name=$m.Files[1].Name;$m|ConvertTo-Json -Depth 8|Set-Content $p}
 }
 Refused {Assert-MsiPackage $copy}
}
if(@(Get-ChildItem -LiteralPath $temp -Recurse -Filter '*.ARMED').Count){throw 'Preparation created an arm marker'}
'PASS real package integrity/local state, repeat/nested-state refusal, tamper/missing/automatic/duplicate refusal; no hardware or firmware access'
