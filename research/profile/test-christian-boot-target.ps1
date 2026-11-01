$ErrorActionPreference='Stop'
$global:bootTargetUsb=$false
function Get-Partition {[pscustomobject]@{IsSystem=$true;Guid='11111111-2222-3333-4444-555555555555';DiskNumber=0;PartitionNumber=1;Offset=1048576;Size=100MB}}
function Get-Disk {param($Number)[pscustomobject]@{PartitionStyle='GPT';BusType=$(if($global:bootTargetUsb){'USB'}else{'NVMe'})}}
function Get-Volume {param([Parameter(ValueFromPipeline)]$InputObject)process{[pscustomobject]@{FileSystem='FAT32';Path='C:\fixture'}}}
function Confirm-SecureBootUEFI {$false}
function Get-FileHash {param($LiteralPath,$Algorithm)if($LiteralPath -notlike '*bootmgfw.efi' -or $Algorithm -cne 'SHA256'){throw 'Unexpected file read'};[pscustomobject]@{Hash='A'*64}}
$fixture=Join-Path $PSScriptRoot ('build/boot-target-test-'+[guid]::NewGuid().ToString('N'))
$entry=Join-Path $PSScriptRoot 'check-christian-boot-target.ps1'
$r=& $entry -Results $fixture | ConvertFrom-Json
$data=Get-ChildItem -LiteralPath $fixture -Recurse -Filter boot-target.json | Get-Content -Raw | ConvertFrom-Json
if(!(Test-Path -LiteralPath $r.evidence_zip) -or (!$data.bootloader_read_error -and $data.windows_bootloader_sha256 -cne ('a'*64)) -or $data.secure_boot_enabled -ne $false -or $data.partition_mounted -or $data.firmware_written){throw 'Wrong report'}
$global:bootTargetUsb=$true;$blocked=$false
try{& $entry -Results ($fixture+'-usb') | Out-Null}catch{$blocked=$true}
if(!$blocked -or (Test-Path ($fixture+'-usb'))){throw 'USB system target accepted'}
Write-Host 'PASS boot target/hash/status packaging and USB refusal; storage/Secure Boot/file queries mocked.'
