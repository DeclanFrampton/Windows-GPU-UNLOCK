# One normal-Windows-boot trace control. No EFI, GPU workload, driver reset or reboot.
param([ValidateSet('Prepare','Collect','Cancel','Finish')][string]$Mode='Prepare',
 [string]$Root='C:\GPU-Unlock',[switch]$AcceptTraceSetup)
$ErrorActionPreference='Stop'
$stateDir=Join-Path $env:ProgramData 'GPUUnlock-MSI-DisplayTrace'
$taskName='GPUUnlock-MSI-DisplayTrace'
$sourceRevision='REPLACE_SOURCE_REVISION'
function Assert-Admin {
 if(!([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Open PowerShell as Administrator, then run this script. Nothing configured.'}
}
function Protect-TraceFile([string]$Path){
 $security=[Security.AccessControl.FileSecurity]::new();$security.SetAccessRuleProtection($true,$false)
 $admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544');$system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18');$security.SetOwner($admins)
 foreach($sid in @($admins,$system)){$security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','Allow'))}
 Set-Acl -LiteralPath $Path -AclObject $security
}
function Invoke-TraceWpr([string[]]$Arguments,[string]$Prefix){
 $quoted=@($Arguments|ForEach-Object {if($_.Contains('"')){throw 'Invalid WPR argument'};'"'+$_+'"'}) -join ' '
 $p=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/wpr.exe') -ArgumentList $quoted -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput (Join-Path $stateDir ($Prefix+'-stdout.txt')) -RedirectStandardError (Join-Path $stateDir ($Prefix+'-stderr.txt'))
 return $p.ExitCode
}
function Read-TraceState {
 $s=Get-Content -LiteralPath (Join-Path $stateDir 'state.json') -Raw|ConvertFrom-Json
 if($s.Schema -cne 'msi-display-boot-trace-v1' -or $s.TaskName -cne $taskName -or $s.Instance -cnotmatch '^MsiDisplay[0-9a-f]{32}$'){throw 'Unrecognized diagnostic state; preserve it'}
 if(@($s.Dependencies).Count -ne 2 -or @($s.Dependencies.Name|Select-Object -Unique).Count -ne 2){throw 'Incomplete trace dependency binding'}
 foreach($entry in $s.Dependencies){if($entry.Name -cnotin @('msi-boot-trace-lib.ps1','msi-display-boot.wprp') -or (Get-FileHash -LiteralPath (Join-Path $stateDir $entry.Name)).Hash.ToLowerInvariant() -cne $entry.Sha256){throw 'Protected trace dependency differs; preserve state'}}
 return $s
}
function Assert-OwnedTask($s){
 $t=Get-ScheduledTask -TaskName $s.TaskName -ErrorAction Stop
 if(@($t.Actions).Count -ne 1 -or $t.Actions[0].Arguments -cne $s.TaskArguments -or $t.Actions[0].Execute -ine $s.TaskExecutable){throw 'Diagnostic task changed; not removing or running it'}
}
if($MyInvocation.InvocationName -eq '.'){return}
try {
Assert-Admin
if($Mode -eq 'Prepare'){
 if(!$AcceptTraceSetup){throw 'Use -AcceptTraceSetup to accept temporary Windows boot tracing plus one SYSTEM startup task, profiling overhead and local ETL metadata. No GPU/EFI action or automatic reboot. Keep USB disconnected.'}
 if(Test-Path -LiteralPath $stateDir){throw 'Diagnostic state already exists; use Collect or Cancel, never overwrite it'}
 if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue){throw 'Task name already exists; preserved'}
 if(!(Test-Path (Join-Path $env:SystemRoot 'System32/wpr.exe'))){throw 'Built-in WPR missing; install nothing'}
 if((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free -lt 2GB){throw 'Need at least 2 GB free for trace processing'}
 [void][IO.Directory]::CreateDirectory($stateDir)
 # The SYSTEM worker must never execute from a user-writable directory.
 $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
 $admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544');$system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18');$acl.SetOwner($admins)
 foreach($sid in @($admins,$system)){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
 Set-Acl -LiteralPath $stateDir -AclObject $acl
 Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $stateDir 'worker.ps1')
 foreach($name in @('msi-boot-trace-lib.ps1','msi-display-boot.wprp')){
  Invoke-WebRequest -UseBasicParsing ('https://raw.githubusercontent.com/DeclanFrampton/Windows-GPU-UNLOCK/'+$sourceRevision+'/research/profile/'+$name) -OutFile (Join-Path $stateDir $name)
 }
 foreach($name in @('worker.ps1','msi-boot-trace-lib.ps1','msi-display-boot.wprp')){Protect-TraceFile (Join-Path $stateDir $name)}
 . (Join-Path $stateDir 'msi-boot-trace-lib.ps1')
 $instance='MsiDisplay'+[guid]::NewGuid().ToString('N')
 $exe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
 $taskArgs='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $stateDir 'worker.ps1')+'" -Mode Finish'
 $dependencies=@(foreach($name in @('msi-boot-trace-lib.ps1','msi-display-boot.wprp')){[ordered]@{Name=$name;Sha256=(Get-FileHash -LiteralPath (Join-Path $stateDir $name)).Hash.ToLowerInvariant()}})
 $state=[ordered]@{Schema='msi-display-boot-trace-v1';Instance=$instance;TaskName=$taskName;TaskExecutable=$exe;TaskArguments=$taskArgs;PreparedBootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');WorkerSha256=(Get-FileHash (Join-Path $stateDir 'worker.ps1')).Hash.ToLowerInvariant();Dependencies=$dependencies;SourceRevision=$sourceRevision;Intent='NormalWindowsControlOnly';EfiRunAuthorized=$false}
 Write-MsiTraceRecord (Join-Path $stateDir 'state.json') $state
 Protect-TraceFile (Join-Path $stateDir 'state.json')
 try{
  $trigger=New-ScheduledTaskTrigger -AtStartup;$trigger.Delay='PT30S'
  $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  Register-ScheduledTask -TaskName $taskName -Action (New-ScheduledTaskAction -Execute $exe -Argument $taskArgs) -Trigger $trigger -Settings $settings -User SYSTEM -RunLevel Highest|Out-Null
  $code=Invoke-TraceWpr @('-boottrace','-addboot',((Join-Path $stateDir 'msi-display-boot.wprp')+'!MsiDisplayBoot'),'-instancename',$instance) 'prepare'
  if($code -ne 0){throw ('WPR preparation failed: '+$code)}
 }catch{
  $failure=$_.Exception.Message
  $cancel=Invoke-TraceWpr @('-boottrace','-cancelboot','-instancename',$instance) 'prepare-cancel'
  if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue){Assert-OwnedTask ([pscustomobject]$state);Unregister-ScheduledTask -TaskName $taskName -Confirm:$false}
  throw ($failure+'; owned trace cleanup exit='+$cancel+'. Preserve diagnostic state and report.')
 }
 Write-Output 'Ready for NORMAL Windows Restart with USB disconnected. No reboot performed. After Windows returns, wait 90 seconds, then run this script -Mode Collect as Administrator.'
 return
}
$state=Read-TraceState
. (Join-Path $stateDir 'msi-boot-trace-lib.ps1')
if($Mode -eq 'Finish'){
 $ops=@{BootUtc={(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')};AssertTask={param($s) Assert-OwnedTask $s};Stop={param($s,$file) Invoke-TraceWpr @('-boottrace','-stopboot',$file,'MSI normal Windows control','-instancename',$s.Instance) 'finish'};Cancel={param($s) Invoke-TraceWpr @('-boottrace','-cancelboot','-instancename',$s.Instance) 'finish-cancel'};RemoveTask={param($s) Assert-OwnedTask $s;Unregister-ScheduledTask -TaskName $s.TaskName -Confirm:$false}}
 Invoke-MsiTraceFinish $stateDir $ops;return
}
if($Mode -eq 'Cancel'){
 $code=Invoke-TraceWpr @('-boottrace','-cancelboot','-instancename',$state.Instance) 'manual-cancel'
 if($code -ne 0){throw ('Owned trace cancellation failed: '+$code+'; preserve state')}
 if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue){Assert-OwnedTask $state;Unregister-ScheduledTask -TaskName $taskName -Confirm:$false}
 Write-MsiTraceRecord (Join-Path $stateDir 'cancel-result.json') @{Cancelled=$true;ExitCode=$code;OwnedTaskRemoved=$true;Utc=[datetime]::UtcNow.ToString('o')}
 Write-Output 'Owned boot trace cancelled and owned task removed. Diagnostic files preserved. No reboot.';return
}
$out=Join-Path $Root ('Results/christian-boot-trace-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
foreach($name in @('state.json','finish-claimed.json','worker-result.json','worker-fatal.json','cancel-result.json','prepare-stdout.txt','prepare-stderr.txt','finish-stdout.txt','finish-stderr.txt','finish-cancel-stdout.txt','finish-cancel-stderr.txt')){if(Test-Path (Join-Path $stateDir $name)){Copy-Item (Join-Path $stateDir $name) $out}}
$resultFile=Join-Path $stateDir 'worker-result.json';$complete=$false
if(Test-Path $resultFile){$r=Get-Content $resultFile -Raw|ConvertFrom-Json;$complete=$r.StopExitCode -eq 0 -and $r.TraceBytes -gt 0 -and $r.OwnedTaskRemoved -eq $true -and !$r.Error}
[ordered]@{ControlTraceComplete=$complete;RawEtlKeptLocal=$true;RawEtlPath=(Join-Path $stateDir 'display-boot.etl');EfiRun=$false;GpuWorkloadRun=$false;Next=$(if($complete){'Return this summary ZIP; keep raw ETL private for now'}else{'If the startup task did not finish, run -Mode Cancel as Administrator and return this report; do not retry setup or boot USB'})}|ConvertTo-Json|Set-Content (Join-Path $out 'result.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip');Write-Output ('Attach this ZIP: '+$out+'.zip')
}catch{
 $failure=$_.Exception.Message
 if($Mode -eq 'Finish'){
  $fatal=Join-Path $stateDir 'worker-fatal.json'
  if(!(Test-Path -LiteralPath $fatal)){[IO.File]::WriteAllText($fatal,(@{Error=$failure;Mode='Finish';Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json))}
  return
 }
 $out=Join-Path $Root ('Results/christian-boot-trace-error-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
 @{Error=$failure;Mode=$Mode;EfiRun=$false;AutomaticReboot=$false;Next='Preserve state and return this ZIP. If tracing was configured, use -Mode Cancel as Administrator; do not boot USB or retry setup.'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
 Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip');Write-Output ('Stopped. Attach this ZIP: '+$out+'.zip')
}
