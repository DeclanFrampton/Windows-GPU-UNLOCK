$ErrorActionPreference='Stop'
Import-Module Microsoft.PowerShell.Utility
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $env:TEMP ('esp-launcher-test-'+[guid]::NewGuid())
$usb=Join-Path $fixture 'usb';$global:fixtureEsp=Join-Path $fixture 'esp';[void](New-Item -ItemType Directory -Path (Join-Path $global:fixtureEsp 'EFI'),$usb -Force)
Set-Content -LiteralPath (Join-Path $global:fixtureEsp 'EFI/EVGA-SHARED-AUDIT.EFI') -Value 'fixture'
if(Test-Path X:\){throw 'X: already exists; no test started'}
& subst X: $usb
if($LASTEXITCODE -ne 0){throw 'Cannot create test drive'}
try {
 function Get-Partition {param([string]$DriveLetter) if($DriveLetter){[pscustomobject]@{DiskNumber=12;IsSystem=$false;IsBoot=$false}}else{[pscustomobject]@{IsSystem=$true;Guid='c36c3e86-02aa-4f76-af1b-96e327f9d1c1'}}}
 function Get-Volume {param([Parameter(ValueFromPipeline=$true)]$InputObject,[string]$DriveLetter) process {if($DriveLetter){[pscustomobject]@{FileSystem='FAT32'}}else{[pscustomobject]@{FileSystem='FAT32';Path=$global:fixtureEsp}}}}
 function Get-Disk {param($Number) [pscustomobject]@{BusType='USB'}}
 function Get-FileHash {param([string]$LiteralPath) if($LiteralPath -eq (Join-Path $global:fixtureEsp 'EFI/EVGA-SHARED-AUDIT.EFI')){[pscustomobject]@{Hash='cfd24d9a1bdcf9fba0c1a7cd0bd314bf494d91c00bb39e3e30d2da87bcd4bbe5'}}else{Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $LiteralPath}}
 & (Join-Path $PSScriptRoot 'stage-shared-esp-launcher.ps1') -Drive X -WindowsEspGuid c36c3e86-02aa-4f76-af1b-96e327f9d1c1 -WhatIf
 if(Test-Path X:\EFI){throw 'WhatIf created files'}
 & (Join-Path $PSScriptRoot 'stage-shared-esp-launcher.ps1') -Drive X -WindowsEspGuid c36c3e86-02aa-4f76-af1b-96e327f9d1c1 -Confirm:$false
 if(!(Test-Path X:\EFI\BOOT\BOOTX64.EFI)){throw 'Launcher missing'}
 $refused=$false
 try {& (Join-Path $PSScriptRoot 'stage-shared-esp-launcher.ps1') -Drive X -WindowsEspGuid c36c3e86-02aa-4f76-af1b-96e327f9d1c1 -Confirm:$false}catch{$refused=$true}
 if(!$refused){throw 'Existing EFI directory was not refused'}
 'USB staging mock passed: WhatIf, copy, and refusal; no physical ESP or USB accessed.'
} finally {& subst X: /D;Remove-Item -LiteralPath $fixture -Recurse -Force}
