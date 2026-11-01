# Final read-only evidence check. No GPU workload, EFI staging, USB writes, installs or reboot.
param([string]$Root='C:\GPU-Unlock',
 [ValidateSet('Ask','Yes','No','Unknown')][string]$AutomaticWindowsReturn='Ask',
 [ValidateSet('Ask','Yes','No','Unknown')][string]$RebootedSinceUnlock='Ask')
$ErrorActionPreference='Stop'
if($AutomaticWindowsReturn -eq 'Ask'){$AutomaticWindowsReturn=Read-Host 'Did Windows start automatically after the unlock USB boot? Yes/No/Unknown'}
if($RebootedSinceUnlock -eq 'Ask'){$RebootedSinceUnlock=Read-Host 'Have you rebooted or powered off since that unlock USB boot? Yes/No/Unknown'}
if($AutomaticWindowsReturn -notin @('Yes','No','Unknown') -or $RebootedSinceUnlock -notin @('Yes','No','Unknown')){throw 'Use Yes, No or Unknown for both answers; nothing changed'}
$results=Join-Path $Root 'Results';$out=Join-Path $results ('christian-final-evidence-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($out)
$errorText=$null;$verified=$false;$bootTime=$null
try {
 $spent=Join-Path $Root 'MSI-POST-VERIFY.SPENT'
 $prior=[IO.Path]::GetFullPath((Get-Content -LiteralPath $spent -Raw -Encoding utf8))
 $allowed=[IO.Path]::GetFullPath($results).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
 if(!$prior.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $prior -Leaf) -notlike 'christian-post-unlock-*'){throw 'Post-unlock report path not recognized'}
 $specs=@{
  'DIAG14.TXT'='e5876d43c796fcfed8ed2e6aa5c9221738706fc2c134054d91cfbcf9b1cb4f7d'
  'benchmark.py'='6a80b3d42de7af14f864a90a957229c44142b97e950eeb0a60bb88a210d11e9a'
  'measurements.json'='92bcfe1fb9b422cb97128f939e8b9eb7299d37d4e42f4b6f15a46355299ff365'
 }
 $hashes=@(foreach($name in $specs.Keys){
  $source=Join-Path $prior $name;$hash=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
  if($hash -ne $specs[$name]){throw ('Reviewed evidence differs: '+$name)}
  Copy-Item -LiteralPath $source -Destination (Join-Path $out $name)
  [ordered]@{name=$name;sha256=$hash}
 })
 $hashes|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'hashes.json') -Encoding utf8
 foreach($name in @('result.json','comparison.json','stderr.txt')){if(Test-Path -LiteralPath (Join-Path $prior $name)){Copy-Item -LiteralPath (Join-Path $prior $name) -Destination $out}}
 $verified=$true
 try{$bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')}catch{$bootTime='Unavailable'}
}catch{$errorText=$_.Exception.Message}
[ordered]@{
 schema='christian-final-evidence-v1';profile='msi-h510-3090-usb';reviewed_files_match=$verified
 automatic_windows_return=$AutomaticWindowsReturn;rebooted_since_unlock=$RebootedSinceUnlock;current_windows_boot_utc=$bootTime
 same_boot_contributor_confirmed=($AutomaticWindowsReturn -eq 'Yes' -and $RebootedSinceUnlock -eq 'No')
 error=$errorText;gpu_workload_run=$false;efi_written=$false;rearmed=$false
 reusable_package_qualified=$false;permanent_unlock_proven=$false;shared_esp_qualified=$false
}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'final-report.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Output ('Attach this ZIP: '+$out+'.zip')
if($errorText){Write-Output ('Evidence check stopped: '+$errorText+'; preserve existing files')}
