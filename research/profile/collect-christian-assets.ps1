# Collect hashes/status only, including incomplete preparation. Never reruns preparation.
param([string]$Root='C:\GPU-Unlock',[string]$Assets)
$ErrorActionPreference='Stop'
if(!$Assets){$Assets=Join-Path $Root 'Assets/ga102'}
$specs=@'
[
  {"Name":"booter_load_ga102.bin","Bytes":61256,"Sha256":"056cbc064a888f80717726c54d7f64fcd68044d123870c95a74f37f4975dcaa4"},
  {"Name":"v67-ga102-610.43.03.bin","Bytes":64000,"Sha256":"2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197"},
  {"Name":"gsp_ga10x.bin","Bytes":84277400,"Sha256":"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
  {"Name":"gsp_boot_ga102.bin","Bytes":24576,"Sha256":"3df651acb174fd5f5561a1996965b192f50c5d763168446ed0d4ead19d895768"},
  {"Name":"gsp_boot_desc_ga102.bin","Bytes":84,"Sha256":"cc5a3fc1f4c47f2fe107b1b68f0176d8a448e6dec84b575e5560ccef5262bf15"}
]

'@ | ConvertFrom-Json
$observed=@(foreach($spec in $specs){
 $file=Join-Path $Assets $spec.Name
 $row=[ordered]@{name=$spec.Name;present=$false;expected_bytes=$spec.Bytes;expected_sha256=$spec.Sha256;bytes=$null;sha256=$null;verified=$false;error=$null}
 try {
  if(Test-Path -LiteralPath $file -PathType Leaf){
   $item=Get-Item -LiteralPath $file
   $row.present=$true;$row.bytes=$item.Length
   if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Link refused'}
   $row.sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
   $row.verified=($row.bytes -eq $spec.Bytes -and $row.sha256 -eq $spec.Sha256)
  }
 }catch{$row.error=$_.Exception.Message}
 [pscustomobject]$row
})
$notices=@(foreach($name in @('NVIDIA-LICENSE','NOTICE.md')){[pscustomobject]@{name=$name;present=(Test-Path -LiteralPath (Join-Path $Assets $name) -PathType Leaf)}})
$work=@();$builds=Join-Path $Root 'Builds'
if(Test-Path -LiteralPath $builds){
 $work=@(Get-ChildItem -LiteralPath $builds -Directory -Filter 'assets-*' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 5 | ForEach-Object {
  [pscustomobject]@{directory=$_.Name;last_write_utc=$_.LastWriteTimeUtc.ToString('o');source_zip_present=(Test-Path -LiteralPath (Join-Path $_.FullName 'source.zip'));payload_source_zip_present=(Test-Path -LiteralPath (Join-Path $_.FullName 'payload-source.zip'));private_python_present=(Test-Path -LiteralPath (Join-Path $_.FullName 'python-env/Scripts/python.exe'))}
 })
}
# Observe only the known payload cache and matching preparation processes.
# Never include command lines, file contents, endpoints or unrelated processes.
function Get-PreparationSnapshot {
 $files=@();$processes=@();$processError=$null
 if(Test-Path -LiteralPath $builds){
  $files=@(Get-ChildItem -LiteralPath $builds -Directory -Filter 'assets-*' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 5 | ForEach-Object {
   $directory=$_.Name
   $cache=Join-Path $_.FullName 'payload-source/gpu-unlock-0ebdb1c6308b6a2072be5bf04513472942541956/inputs'
   foreach($candidate in @($cache,(Join-Path $cache 'inputs'))){
    if(Test-Path -LiteralPath $candidate){
     Get-ChildItem -LiteralPath $candidate -File -Force | Select-Object -First 10 | ForEach-Object {
      [pscustomobject]@{directory=$directory;cache_subdirectory=(Split-Path $candidate -Leaf);name=$_.Name;bytes=$_.Length;last_write_utc=$_.LastWriteTimeUtc.ToString('o')}
     }
    }
   }
  })
 }
 try {
  $processes=@(Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'" -ErrorAction Stop | Where-Object {
   $_.CommandLine -and $_.CommandLine.IndexOf([IO.Path]::GetFullPath($builds),[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.CommandLine.Contains('prepare-evga3090-assets.py')
  } | ForEach-Object {
   [pscustomobject]@{process_id=$_.ProcessId;cpu_seconds=([double]$_.KernelModeTime+[double]$_.UserModeTime)/10000000;working_set_bytes=[long]$_.WorkingSetSize}
  })
 }catch{$processError='Preparation process inventory unavailable'}
 [pscustomobject]@{sample_utc=[DateTime]::UtcNow.ToString('o');cache_files=$files;preparation_processes=$processes;process_inventory_error=$processError}
}
$first=Get-PreparationSnapshot
Start-Sleep -Seconds 2
$second=Get-PreparationSnapshot
$complete=@($observed | Where-Object {!$_.verified}).Count -eq 0 -and @($notices | Where-Object {!$_.present}).Count -eq 0
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$out=Join-Path $results ('christian-assets-result-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
[ordered]@{test='christian-assets-collection-v2';progress_samples=@($first,$second);preparation_complete=$complete;assets_directory=$Assets;assets=$observed;notices=$notices;recent_preparation_directories=$work;gpu_accessed=$false;efi_staged=$false;unlock_attempted=$false;preparation_retried=$false} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding utf8
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
if(!(Test-Path -LiteralPath $zip -PathType Leaf) -or (Get-Item -LiteralPath $zip).Length -le 0){throw 'Report ZIP creation failed; send this error'}
Write-Output ('Preparation complete at collection: '+$complete)
Write-Output ('Attach this ZIP: '+$zip)
Write-Output 'Collection only: preparation was not retried. Do not reboot or upload firmware files.'
