# Verify performance after the completed MSI transaction. No EFI staging, installs or reboot.
param([string]$Root='C:\GPU-Unlock',[switch]$AcceptBenchmarkRisk,[switch]$AfterRestart)
$ErrorActionPreference='Stop'
$bootUtc=$null
if($AfterRestart){
 $bootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
 if($bootUtc -le [datetime]::Parse('2026-11-01T23:26:59.5000000Z').ToUniversalTime()){throw 'A later Windows boot is required. This script does not restart the computer.'}
}
$results=Join-Path $Root 'Results'
$priorMarker=Join-Path $Root 'MSI-UNLOCK-BENCHMARK.SPENT'
$prior=[IO.Path]::GetFullPath((Get-Content -LiteralPath $priorMarker -Raw -Encoding utf8))
$allowed=[IO.Path]::GetFullPath($results).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if(!$prior.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $prior)){throw 'Prior unlock result missing; preserve files and send error'}
$diag=Get-ChildItem -LiteralPath (Join-Path $prior 'RTX3090-UNLOCK') -Filter 'DIAG??.TXT' -File | Sort-Object Name -Descending | Select-Object -First 1
$text=Get-Content -LiteralPath $diag.FullName -Raw
if(!$text.Contains('msi-unlock-transaction-complete status=0x0000000000000000') -or !$text.Contains('diagnostic-result status=0x0000000000000000') -or @([regex]::Matches($text,'msi-unlock-ss0-value status=0x0000000088888888')).Count -ne 2 -or @([regex]::Matches($text,'msi-unlock-ss1-value status=0x0000000000000008')).Count -ne 2){throw 'Successful MSI transaction evidence missing; no workload'}
$sources=@(Get-ChildItem -LiteralPath $prior -Directory -Filter 'post-benchmark-christian-torch-baseline-*')
if($sources.Count -ne 1){throw 'Expected one prior benchmark source; preserve files and send error'}
$source=Join-Path $sources[0].FullName 'benchmark.py'
if((Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant() -ne '6a80b3d42de7af14f864a90a957229c44142b97e950eeb0a60bb88a210d11e9a'){throw 'Benchmark source differs; no workload'}
$original=Join-Path $results ($sources[0].Name.Substring('post-benchmark-'.Length))
$existing=Join-Path $original 'measurements.json'
$claim=Join-Path $Root $(if($AfterRestart){'MSI-POST-RESTART.SPENT'}else{'MSI-POST-VERIFY.SPENT'})
if(Test-Path -LiteralPath $claim){throw ('Already attempted. Do not retry. Return the folder/ZIP recorded in '+$claim)}
if(!$AcceptBenchmarkRisk){throw 'Use -AcceptBenchmarkRisk only to accept one existing CUDA benchmark workload (GPU load, possible driver error/hang). No EFI, install, reset or reboot is performed. Do not rerun the unlock. If Windows hangs, stop; manual recovery may lose the current GPU state.'}
$py=Join-Path $Root 'BenchmarkEnv-v1/Scripts/python.exe'
if(!(Test-Path -LiteralPath $py)){throw 'Existing environment missing; install nothing and send error'}
$running=@(Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine -match 'benchmark\.py'})
if($running.Count){throw 'A benchmark process is still running. Wait; do not start another. Send this message.'}
$prefix=if($AfterRestart){'christian-post-restart-'}else{'christian-post-unlock-'}
$out=Join-Path $results ($prefix+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($out)
$file=[IO.File]::Open($claim,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$bytes=[Text.Encoding]::UTF8.GetBytes($out);$file.Write($bytes,0,$bytes.Length)}finally{$file.Dispose()}
$errorText=$null;$exitCode=$null;$reused=$false
try {
 Copy-Item -LiteralPath $source -Destination (Join-Path $out 'benchmark.py')
 Copy-Item -LiteralPath $diag.FullName -Destination (Join-Path $out $diag.Name)
 if(!$AfterRestart -and (Test-Path -LiteralPath $existing)){Copy-Item -LiteralPath $existing -Destination (Join-Path $out 'measurements.json');$reused=$true}
 else {
  # File redirection keeps harmless Python warnings out of PowerShell's terminating error stream.
  $args='"'+(Join-Path $out 'benchmark.py')+'" "'+(Join-Path $out 'measurements.json')+'"'
  $process=Start-Process -FilePath $py -ArgumentList $args -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $out 'stdout.txt') -RedirectStandardError (Join-Path $out 'stderr.txt')
  $exitCode=$process.ExitCode
  if($exitCode -ne 0){throw ('Benchmark exit code '+$exitCode+'; do not retry')}
 }
 $report=Get-Content -LiteralPath (Join-Path $out 'measurements.json') -Raw | ConvertFrom-Json
 if($report.schema -ne 'christian-torch-baseline-v1' -or $report.torch -ne '2.14.1+cu126' -or @($report.measurements).Count -ne 4){throw 'Unexpected benchmark report; no performance conclusion'}
 $baseline=@{fp32=23.4893;fp16_output=67.2944;bf16_output=68.3738;tf32=33.8468}
 $comparison=@(foreach($row in $report.measurements){
  if(!$baseline.ContainsKey($row.mode) -or $row.n -ne 4096 -or $row.reference_checked_n -ne 128 -or [double]$row.median_tflops -le 0 -or [double]::IsNaN([double]$row.median_tflops) -or [double]::IsInfinity([double]$row.median_tflops)){throw 'Invalid measurement; no performance conclusion'}
  [ordered]@{mode=$row.mode;before_tflops=$baseline[$row.mode];after_tflops=$row.median_tflops;ratio=([double]$row.median_tflops/$baseline[$row.mode])}
 })
 $comparison | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'comparison.json') -Encoding utf8
}catch{$errorText=$_.Exception.Message}
[ordered]@{after_restart=$AfterRestart.IsPresent;current_windows_boot_utc=if($bootUtc){$bootUtc.ToString('o')}else{$null};reused_completed_measurement=$reused;process_exit_code=$exitCode;error=$errorText;efi_repeated=$false;installed=$false;windows_return_path='report automatic or manual; mention any intervening reboot';performance_conclusion='Review measurements and return path before attributing speedup'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
Write-Output ('Attach this ZIP: '+$zip)
if($errorText){Write-Output ('Stopped: '+$errorText+'; do not retry')}
