# Windows-only setup diagnostics. No device, boot or firmware writes.
[CmdletBinding()]
param([switch]$SelfTest)
$ErrorActionPreference='Stop'
function Public-DriverLabel($Value) {
 if($Value -isnot [string] -or $Value.Length -gt 128 -or $Value -match '[\\/:@\x00-\x1f]'){return $null}
 return $Value
}
function Get-PreflightReport([bool]$Elevated,[scriptblock]$QuerySecureBoot,$Video,$Drivers) {
 $secure=[ordered]@{State='unknown';ErrorCategory=$null;HResult=$null}
 try {
  $value=& $QuerySecureBoot
  if($value -isnot [bool]){throw 'Unexpected query result.'}
  $secure.State=if($value){'enabled'}else{'disabled'}
 } catch {
  $secure.ErrorCategory=[string]$_.CategoryInfo.Category
  $secure.HResult='0x'+([Convert]::ToString([int]$_.Exception.HResult,16)).PadLeft(8,'0')
 }
 $adapters=@();$index=0
 foreach($v in $Video){
  $token=$null
  if([string]$v.PNPDeviceID -match '^([A-Za-z][A-Za-z0-9_-]{0,31})\\'){$token=$Matches[1]}
  $matchesDriver=@($Drivers | Where-Object {$_.DeviceID -and $_.DeviceID -ceq $v.PNPDeviceID})
  $details=@($matchesDriver | ForEach-Object {
   [ordered]@{Provider=(Public-DriverLabel $_.DriverProviderName);Manufacturer=(Public-DriverLabel $_.Manufacturer);
    Version=(Public-DriverLabel $_.DriverVersion);Inf=(Public-DriverLabel $_.InfName);Signed=($_.IsSigned -eq $true)}
  })
  $adapters += [ordered]@{Index=$index;EnumeratorToken=$token;MatchingDriverCount=$details.Count;Drivers=$details};$index++
 }
 return [ordered]@{SchemaVersion=1;Elevated=$Elevated;SecureBoot=$secure;DisplayAdapters=$adapters;
   HardwareTested=$false;WriteEligible=$false;Next='Keep EFI preparation stopped until reviewed. No settings changes or boot.'}
}
if($SelfTest){
 $video=@([pscustomobject]@{PNPDeviceID='LCI\PRIVATE'})
 $drivers=@([pscustomobject]@{DeviceID='LCI\PRIVATE';DriverProviderName='Example Display';Manufacturer='Example';DriverVersion='1.2.3';InfName='oem1.inf';IsSigned=$true},[pscustomobject]@{DeviceID='OTHER\PRIVATE';DriverProviderName='WRONG'})
 foreach($enabled in @($true,$false)){
  $query={ $enabled }.GetNewClosure();$r=Get-PreflightReport $false $query $video $drivers
  $expected=if($enabled){'enabled'}else{'disabled'}
  if($r.SecureBoot.State -ne $expected -or $r.DisplayAdapters[0].MatchingDriverCount -ne 1 -or $r.DisplayAdapters[0].Drivers[0].Provider -ne 'Example Display'){throw 'Preflight state/driver regression'}
 }
 $r=Get-PreflightReport $false {throw 'PRIVATE ERROR PATH'} $video $drivers
 $json=$r|ConvertTo-Json -Depth 8
 if($r.SecureBoot.State -ne 'unknown' -or $json.Contains('PRIVATE') -or $json.Contains('WRONG') -or (Public-DriverLabel 'C:\PRIVATE\FILE')){throw 'Preflight failure/redaction regression'}
 $r=Get-PreflightReport $true {'false'} @() @()
 if($r.SecureBoot.State -ne 'unknown' -or $r.WriteEligible){throw 'Unknown state must not become disabled'}
 Write-Host 'PASS: enabled/disabled/unknown states, driver association, redaction, non-boolean refusal.';exit
}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$elevated=([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$report=Get-PreflightReport $elevated {Confirm-SecureBootUEFI -ErrorAction Stop} @(Get-CimInstance Win32_VideoController) @(Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceClass='DISPLAY'")
$docs=[Environment]::GetFolderPath('MyDocuments');if(!$docs){throw 'Documents folder unavailable.'}
$out=Join-Path $docs ('GPU-Unlock-Preflight-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $out|Out-Null
$path=Join-Path $out 'windows-preflight.json';$report|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding UTF8
Write-Host ('Review and return only '+$path+'. Keep EFI preparation stopped; do not change settings or boot.')
