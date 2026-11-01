# Windows-only finalization from complete cached inputs; never runs an EFI or stops processes.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$revision='34f64b0ff1445ee32d2bdd9301b5bd0e30ce2098'
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$out=Join-Path $results ('christian-assets-finish-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
$log=Join-Path $out 'preparation.txt';'Windows-only cached payload finalization' | Set-Content -LiteralPath $log
$complete=$false;$failure=$null;$verified=@();$cache=$null
try {
 $builds=Join-Path $Root 'Builds'
 $active=@(Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'" -ErrorAction Stop | Where-Object {$_.CommandLine -and $_.CommandLine.IndexOf([IO.Path]::GetFullPath($builds),[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.CommandLine.Contains('prepare-evga3090-assets.py')})
 if($active.Count){throw 'A preparation worker is still active. No worker was stopped and no duplicate was started.'}
 $previous=@(Get-ChildItem -LiteralPath $builds -Directory -Filter 'assets-*' | Sort-Object LastWriteTimeUtc -Descending)
 $runner=$null;$sourceZip=$null
 foreach($directory in $previous){
  $candidate=Join-Path $directory.FullName 'python-env/Scripts/python.exe'
  if(!$runner -and (Test-Path -LiteralPath $candidate)){
   & $candidate -I -c 'import zstandard' *> $null
   if($LASTEXITCODE -eq 0){$runner=$candidate}
  }
  $zip=Join-Path $directory.FullName 'payload-source.zip'
  if(!$sourceZip -and (Test-Path -LiteralPath $zip) -and (Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant() -eq 'd0d8ecd989f9cb885d8eb9ab39fb3f36c9c66df2efd9fabaa68f8afc8bbe70fb'){$sourceZip=$zip}
  $base=Join-Path $directory.FullName 'payload-source/gpu-unlock-0ebdb1c6308b6a2072be5bf04513472942541956/inputs'
  foreach($candidateCache in @($base,(Join-Path $base 'inputs'))){
   if(!$cache -and (Test-Path -LiteralPath (Join-Path $candidateCache 'NVIDIA-kernel-module-source-610.43.03.tar.xz')) -and (Test-Path -LiteralPath (Join-Path $candidateCache 'nvidia-utils-610.43.03-1-x86_64_v3.pkg.tar.zst'))){$cache=$candidateCache}
  }
 }
 if(!$runner -or !$sourceZip -or !$cache){throw 'Complete cached inputs or prepared Python environment missing. Preserved everything; no payload download was started.'}
 $work=Join-Path $builds ('finish-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($work)
 Write-Output 'Verifying cached inputs and preparing payloads. No new NVIDIA download or USB boot.'
 Invoke-WebRequest -UseBasicParsing ('https://github.com/DeclanFrampton/Windows-GPU-UNLOCK/archive/'+$revision+'.zip') -OutFile (Join-Path $work 'source.zip')
 Expand-Archive -LiteralPath (Join-Path $work 'source.zip') -DestinationPath $work
 $repo=Join-Path $work ('Windows-GPU-UNLOCK-'+$revision);$assets=Join-Path $Root 'Assets/ga102'
 $generator=Join-Path $repo 'research/profile/prepare-evga3090-assets.py'
 if((Test-Path -LiteralPath $assets) -and @(Get-ChildItem -LiteralPath $assets -Force).Count){
  & $runner -I $generator --verify-only --output $assets *> $log
 }else{
  & $runner -I $generator --source (Join-Path $work 'payload-source') --source-zip $sourceZip --input-cache $cache --output $assets *> $log
 }
 if($LASTEXITCODE -ne 0){throw 'Cached preparation failed; details are included in the report. No payload download or GPU action was attempted.'}
 $specs=Get-Content -LiteralPath (Join-Path $repo 'internal-boot/unlock/assets.json') -Raw | ConvertFrom-Json
 $verified=@(foreach($spec in $specs){
  $file=Join-Path $assets $spec.Name;$item=Get-Item -LiteralPath $file
  if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Payload link refused'}
  $hash=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()
  if($item.Length -ne $spec.Bytes -or $hash -ne $spec.Sha256){throw ('Payload mismatch: '+$spec.Name)}
  [pscustomobject]@{name=$spec.Name;bytes=$item.Length;sha256=$hash}
 })
 foreach($name in @('NVIDIA-LICENSE','NOTICE.md')){if(!(Test-Path -LiteralPath (Join-Path $assets $name) -PathType Leaf)){throw ('Required notice missing: '+$name)}}
 $complete=$true
}catch{$failure=$_.Exception.Message}
[ordered]@{test='christian-cached-payload-finalization-v1';preparation_complete=$complete;error=$failure;assets=$verified;input_cache=$cache;source_revision=$revision;gpu_accessed=$false;efi_staged=$false;unlock_attempted=$false;payload_download_attempted=$false} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Output ('Preparation complete: '+$complete)
if($failure){Write-Output ('Stopped: '+$failure)}
Write-Output ('Attach this ZIP: '+$out+'.zip')
Write-Output 'No reboot. Keep firmware locally; the report ZIP contains no firmware.'
