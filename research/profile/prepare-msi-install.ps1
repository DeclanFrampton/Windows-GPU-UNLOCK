# Local installer state preparation only. Deliberately has no arm or firmware writer.
param([Parameter(Mandatory)][string]$PackageDirectory,[string]$StateDirectory='C:\GPU-Unlock\MSI-Profile',
 [ValidatePattern('^[0-9a-f]{64}$')][string]$ReviewedEvidenceSha256='e5876d43c796fcfed8ed2e6aa5c9221738706fc2c134054d91cfbcf9b1cb4f7d')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'msi-package-lib.ps1')
. (Join-Path $PSScriptRoot 'msi-attempt-lib.ps1')
$m=Assert-MsiPackage $PackageDirectory
$state=[IO.Path]::GetFullPath($StateDirectory)
$systemRoot=[IO.Path]::GetFullPath($env:SystemDrive+'\')
if(!$state.StartsWith($systemRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Preparation state must stay on the Windows system volume, outside USB/ESP'}
$sourceRoot=[IO.Path]::GetFullPath($PackageDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if(($state+[IO.Path]::DirectorySeparatorChar).StartsWith($sourceRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'State must be outside the source package'}
if(Test-Path -LiteralPath $state){throw 'State already exists; preserve it, do not overwrite or retry'}
for($p=(Split-Path $state -Parent);$p;){
 if((Test-Path -LiteralPath $p) -and ([IO.File]::GetAttributes($p) -band [IO.FileAttributes]::ReparsePoint)){throw 'State parent must not be a reparse point'}
 $next=Split-Path $p -Parent;if($next -eq $p){break};$p=$next
}
[void][IO.Directory]::CreateDirectory($state)
$package=Join-Path $state 'Package';Copy-Item -LiteralPath ([IO.Path]::GetFullPath($PackageDirectory)) -Destination $package -Recurse
$null=Assert-MsiPackage $package
$attemptPlan=New-MsiAttemptPlan $state $package $ReviewedEvidenceSha256
$plan=[ordered]@{
 Schema='msi-install-preparation-v1';ProfileId=$m.ProfileId;PackageSha256=(Get-MsiPackageHash (Join-Path $package 'package.json'))
 PackageDirectory=$package;AttemptPlan=$attemptPlan;State='PreparedNotInstalled';Installed=$false;Armed=$false;FirmwareWritten=$false;AutomaticReboot=$false
 AttendedRearm=[ordered]@{Enabled=$false;Required=@('Unique per-attempt identity and durable started/finished receipts','Reject pending/failed/ambiguous attempts; never recreate consumed markers','Read back EFI/assets and bind package/profile/evidence hashes','Review exact backup/restore ownership and normal Windows return','One informed attended rearm validation before reusable qualification')}
 Unattended=[ordered]@{Enabled=$false;Required=@('Reusable attended path qualified first','Boot handoff and failure behavior validated independently','Bounded persistent opt-in with attempt budget and explicit disable path','No automatic retry after failed or incomplete attempt')}
 Persistence=[ordered]@{Proven=$false;Required=@('Compare normal restart without EFI','Distinguish restart persistence from full-power-off behavior','Do not describe a per-boot installer as permanent hardware unlock')}
}
$plan|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $state 'installation-plan.json') -Encoding utf8
[ordered]@{prepared=$true;installed=$false;armed=$false;plan=(Join-Path $state 'installation-plan.json')}|ConvertTo-Json
