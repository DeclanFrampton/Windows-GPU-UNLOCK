# Inspect existing preparation only. Never rebuilds, deletes, arms or upgrades it.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$state=Join-Path $Root 'MSI-Profile-Preparation';$package=Join-Path $state 'Package'
$results=Join-Path $Root 'Results';$out=Join-Path $results ('christian-preparation-report-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($out)
$complete=$false;$errorText=$null;$hasAttempt=$false
try {
 foreach($path in @($state,$package)){if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Preparation path is a reparse point; preserved'}}
 $planPath=Join-Path $state 'installation-plan.json'
 $plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
 if($plan.Schema -cne 'msi-install-preparation-v1' -or $plan.State -cne 'PreparedNotInstalled' -or $plan.Installed -ne $false -or $plan.Armed -ne $false -or $plan.AttendedRearm.Enabled -ne $false -or $plan.Unattended.Enabled -ne $false){throw 'Unexpected existing installation policy'}
 $packagePath=Join-Path $package 'package.json'
 if((Get-FileHash -LiteralPath $packagePath).Hash.ToLowerInvariant() -cne $plan.PackageSha256){throw 'Package manifest no longer matches preparation plan'}
 $m=Get-Content -LiteralPath $packagePath -Raw|ConvertFrom-Json
 if($m.Schema -cne 'msi-attended-preparation-v1' -or $m.ProfileId -cne 'msi-h510-3090-usb' -or $m.Layout -cne 'Usb' -or $m.RearmEnabled -ne $false -or $m.AutomaticUnlock -ne $false -or $m.PermanentUnlock -ne $false -or $m.AssetsBundled -ne $false){throw 'Unexpected existing package policy'}
 $expected=@('UNLOCK.EFI','profile.json','assets.json','source-manifest.json','pe-verification.json','LICENSE','README.md')
 if(@($m.Files).Count -ne $expected.Count){throw 'Incomplete package inventory'}
 foreach($name in $expected){
  $entries=@($m.Files|Where-Object {$_.Name -ceq $name});if($entries.Count -ne 1){throw 'Duplicate/missing package entry'}
  $path=Join-Path $package $name;$item=Get-Item -LiteralPath $path
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -ne $entries[0].Bytes -or (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $entries[0].Sha256){throw ('Existing file differs: '+$name)}
 }
 $profile=Get-Content -LiteralPath (Join-Path $package 'profile.json') -Raw|ConvertFrom-Json
 $source=Get-Content -LiteralPath (Join-Path $package 'source-manifest.json') -Raw|ConvertFrom-Json
 if($profile.machine_profile -cne 'GU_PROFILE_MSI_H510_3090' -or $profile.subsystem_id -cne '38811462' -or $source.MsiUnlock -ne $true -or $source.EfiSha256 -cne (Get-FileHash -LiteralPath (Join-Path $package 'UNLOCK.EFI')).Hash.ToLowerInvariant()){throw 'Existing profile/build differs'}
 Copy-Item -LiteralPath $planPath -Destination $out
 foreach($name in @('package.json','profile.json','source-manifest.json','pe-verification.json')){Copy-Item -LiteralPath (Join-Path $package $name) -Destination $out}
 $attempt=Join-Path $state 'Attempts/attempt-0001.json'
 if(Test-Path -LiteralPath $attempt){Copy-Item -LiteralPath $attempt -Destination $out;$hasAttempt=$true}
 $complete=$true
}catch{$errorText=$_.Exception.Message}
if(Test-Path -LiteralPath $state){@(Get-ChildItem -LiteralPath $state -Force|Select-Object Name,Length,Attributes)|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'state-inventory.json') -Encoding utf8}
[ordered]@{existing_preparation_complete=$complete;error=$errorText;attempt_plan_present=$hasAttempt;existing_state_modified=$false;rebuilt=$false;installed=$false;armed=$false;gpu_accessed=$false;firmware_written=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Output ('Attach this ZIP: '+$out+'.zip')
