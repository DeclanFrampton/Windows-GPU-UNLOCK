# Package preparation only. No hardware, firmware or USB mutation.
function Get-MsiPackageHash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Assert-MsiPackage([string]$Directory){
 $root=[IO.Path]::GetFullPath($Directory)
 if(([IO.File]::GetAttributes($root) -band [IO.FileAttributes]::ReparsePoint)){throw 'Package root must not be a reparse point'}
 $m=Get-Content -LiteralPath (Join-Path $root 'package.json') -Raw|ConvertFrom-Json
 if($m.Schema -cne 'msi-attended-preparation-v1' -or $m.ProfileId -cne 'msi-h510-3090-usb' -or $m.Layout -cne 'Usb' -or $m.AutomaticUnlock -ne $false -or $m.RearmEnabled -ne $false -or $m.PermanentUnlock -ne $false -or $m.AssetsBundled -ne $false){throw 'Unsupported MSI package policy'}
 $expected=@('UNLOCK.EFI','profile.json','assets.json','source-manifest.json','pe-verification.json','LICENSE','README.md')
 if(@($m.Files).Count -ne $expected.Count){throw 'Incomplete package inventory'}
 foreach($name in $expected){
  $entry=@($m.Files|Where-Object {$_.Name -ceq $name});if($entry.Count -ne 1){throw 'Invalid package inventory'}
  $path=Join-Path $root $name;$item=Get-Item -LiteralPath $path
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.PSIsContainer -or $item.Length -ne $entry[0].Bytes -or (Get-MsiPackageHash $path) -cne $entry[0].Sha256){throw ('Package integrity failed: '+$name)}
 }
 $profile=Get-Content -LiteralPath (Join-Path $root 'profile.json') -Raw|ConvertFrom-Json
 $source=Get-Content -LiteralPath (Join-Path $root 'source-manifest.json') -Raw|ConvertFrom-Json
 if($profile.machine_profile -cne 'GU_PROFILE_MSI_H510_3090' -or $profile.pci_id -cne '220410de' -or $profile.subsystem_id -cne '38811462' -or $source.MsiUnlock -ne $true -or $source.WritesFirmwareVariables -ne $false -or $source.EfiSha256 -cne (Get-MsiPackageHash (Join-Path $root 'UNLOCK.EFI'))){throw 'Package profile/build mismatch'}
 return $m
}
