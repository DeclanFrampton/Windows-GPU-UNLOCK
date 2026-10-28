$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$testRoot=Join-Path $repo ('research/profile/build/stage-fixture-'+[guid]::NewGuid().ToString('N'))
if(Get-PSDrive Q -ErrorAction SilentlyContinue){throw 'Q already used'}
New-Item -ItemType Directory -Path "$testRoot/RTX3090-UNLOCK","$testRoot/EFI/BOOT" -Force | Out-Null
New-PSDrive -Name Q -PSProvider FileSystem -Root $testRoot | Out-Null
try {
 function Get-Partition {param($DriveLetter) if($DriveLetter){[pscustomobject]@{DiskNumber=999;IsSystem=$false;IsBoot=$false}}else{[pscustomobject]@{Guid='c36c3e86-02aa-4f76-af1b-96e327f9d1c1';IsSystem=$true}}}
 function Get-Volume {param($DriveLetter) [pscustomobject]@{FileSystem='FAT32'}}
 function Get-Disk {param($Number) [pscustomobject]@{BusType='USB'}}
 foreach($i in 5..16){Copy-Item -LiteralPath (Join-Path $repo ('research/profile/build/evga-first-live-result/EVGA{0:D2}.TXT' -f $i)) -Destination "$testRoot/RTX3090-UNLOCK"}
 Copy-Item -LiteralPath 'research/profile/build/evga-first-live-result/EVGA17.TXT' -Destination "$testRoot/RTX3090-UNLOCK/EVGA17.TXT"
 Set-Content -LiteralPath "$testRoot/RTX3090-UNLOCK/EVGA-UNLOCK.ARMED" -Value 'prior attempt marker'
 Set-Content -LiteralPath "$testRoot/RTX3090-UNLOCK/DIAG00.TXT" -Value 'synthetic existence fixture'
 Set-Content -LiteralPath "$testRoot/RTX3090-UNLOCK/DIAG01.TXT" -Value 'synthetic existence fixture'
 Set-Content -LiteralPath "$testRoot/RTX3090-UNLOCK/EVGA-PLATFORM-PROBE.ARMED" -Value 'preserve old marker'
 Set-Content -LiteralPath "$testRoot/RTX3090-UNLOCK/EVGA-RESOURCES-PROBE.ARMED" -Value 'preserve old marker'
 Set-Content -LiteralPath "$testRoot/EFI/BOOT/BOOTX64.EFI" -Value 'previous EFI fixture'
 $old=(Get-FileHash "$testRoot/EFI/BOOT/BOOTX64.EFI").Hash
 $refused=$false;try {& ./research/profile/stage-evga-text-stop.ps1 -Drive Q -WhatIf}catch{if($_ -match 'Explicit -AttemptUnlock'){$refused=$true}else{throw}}
 if(!$refused){throw 'Unlock mode did not require explicit switch'}
 & ./research/profile/stage-evga-text-stop.ps1 -Drive Q -AttemptUnlock -WhatIf
 if(Test-Path "$testRoot/RTX3090-UNLOCK/ASSETS"){throw 'WhatIf wrote assets'}
 & ./research/profile/stage-evga-text-stop.ps1 -Drive Q -AttemptUnlock
 if((Get-FileHash "$testRoot/EFI/BOOT/BOOTX64.before-evga-text-stop.efi").Hash -ne $old){throw 'backup mismatch'}
 if((Get-FileHash "$testRoot/EFI/BOOT/BOOTX64.EFI").Hash -ne (Get-FileHash 'internal-boot/boot/build/evga-text-stop/BOOTX64.EFI').Hash){throw 'EFI mismatch'}
 if(!(Test-Path "$testRoot/RTX3090-UNLOCK/EVGA-PLATFORM-PROBE.ARMED") -or !(Test-Path "$testRoot/RTX3090-UNLOCK/EVGA-RESOURCES-PROBE.ARMED")){throw 'old marker removed'}
 foreach($a in (Get-Content internal-boot/unlock/assets.json -Raw | ConvertFrom-Json)){if((Get-FileHash "$testRoot/RTX3090-UNLOCK/ASSETS/$($a.Name)").Hash.ToLowerInvariant() -ne $a.Sha256){throw 'asset mismatch'}}
 Set-Content -LiteralPath "$testRoot/RTX3090-UNLOCK/EVGA-UNLOCK2.ARMED" -Value 'synthetic spent marker'
 $refused=$false;try {& ./research/profile/stage-evga-text-stop.ps1 -Drive Q -AttemptUnlock}catch{if($_ -match 'attempt is already armed'){$refused=$true}else{throw}}
 if(!$refused){throw 'spent marker not refused'}
 'Unlock staging fixture passed explicit mode, WhatIf no writes, exact EFI/asset copies, backup, old marker preservation and spent-marker refusal. Storage inventory mocked; no USB accessed.'
} finally {Remove-PSDrive Q}
