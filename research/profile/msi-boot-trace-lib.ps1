# Recorder lifecycle. No operation at import. OS mutations are supplied by the entry script.
function Write-MsiTraceRecord([string]$Path,$Value){
 $data=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 6))
 $file=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$file.Write($data,0,$data.Length);$file.Flush($true)}finally{$file.Dispose()}
}
function Invoke-MsiTraceFinish([string]$StateDirectory,$Ops){
 $state=Get-Content -LiteralPath (Join-Path $StateDirectory 'state.json') -Raw|ConvertFrom-Json
 if($state.Schema -cne 'msi-display-boot-trace-v1' -or $state.Instance -cnotmatch '^MsiDisplay[0-9a-f]{32}$'){throw 'Unrecognized trace state'}
 $boot=& $Ops.BootUtc
 if($boot -eq $state.PreparedBootUtc){throw 'Wait for a normal Windows restart; this script never reboots'}
 if((Get-FileHash -LiteralPath (Join-Path $StateDirectory 'worker.ps1')).Hash.ToLowerInvariant() -cne $state.WorkerSha256){throw 'Protected worker differs; no trace action'}
 & $Ops.AssertTask $state
 Write-MsiTraceRecord (Join-Path $StateDirectory 'finish-claimed.json') @{BootUtc=$boot;StartedUtc=[datetime]::UtcNow.ToString('o')}
 $stopCode=$null;$cancelCode=$null;$taskRemoved=$false;$errorText=$null
 try{
  $stopCode=& $Ops.Stop $state (Join-Path $StateDirectory 'display-boot.etl')
  if($stopCode -ne 0){throw ('WPR stopboot failed: '+$stopCode)}
 }catch{
  $errorText=$_.Exception.Message
  try{$cancelCode=& $Ops.Cancel $state}catch{$errorText+='; owned trace cancellation failed: '+$_.Exception.Message}
 }finally{
  try{& $Ops.RemoveTask $state;$taskRemoved=$true}catch{$errorText+='; owned task removal failed: '+$_.Exception.Message}
 }
 $trace=Join-Path $StateDirectory 'display-boot.etl';$bytes=0;$hash=$null
 if(Test-Path -LiteralPath $trace){$bytes=(Get-Item -LiteralPath $trace).Length;$hash=(Get-FileHash -LiteralPath $trace).Hash.ToLowerInvariant()}
 Write-MsiTraceRecord (Join-Path $StateDirectory 'worker-result.json') ([ordered]@{Schema='msi-display-boot-result-v1';BootUtc=$boot;FinishedUtc=[datetime]::UtcNow.ToString('o');StopExitCode=$stopCode;CancelExitCode=$cancelCode;OwnedTaskRemoved=$taskRemoved;TraceBytes=$bytes;TraceSha256=$hash;Error=$errorText;GpuWorkloadRun=$false;EfiRun=$false;FirmwareWritten=$false})
}
