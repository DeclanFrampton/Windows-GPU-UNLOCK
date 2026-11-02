$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'msi-boot-trace-lib.ps1')
$base=Join-Path $env:TEMP ('msi-trace-tests-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($base)
foreach($case in @('success','stop-failure','cancel-failure','remove-failure','same-boot','changed-worker','changed-task','duplicate-claim')){
 $root=Join-Path $base $case;[void][IO.Directory]::CreateDirectory($root)
 Set-Content -LiteralPath (Join-Path $root 'worker.ps1') 'mock worker'
 Write-MsiTraceRecord (Join-Path $root 'state.json') @{Schema='msi-display-boot-trace-v1';Instance=('MsiDisplay'+('a'*32));PreparedBootUtc='old-boot';WorkerSha256=(Get-FileHash (Join-Path $root 'worker.ps1')).Hash.ToLowerInvariant()}
 $counts=[pscustomobject]@{Stop=0;Cancel=0;Remove=0}
 $ops=@{BootUtc={if($case -eq 'same-boot'){'old-boot'}else{'new-boot'}};AssertTask={param($s) if($case -eq 'changed-task'){throw 'Task changed'}};Stop={param($s,$file) $counts.Stop++;if($case -in @('stop-failure','cancel-failure')){2}else{[IO.File]::WriteAllText($file,'synthetic ETL fixture');0}};Cancel={param($s) $counts.Cancel++;if($case -eq 'cancel-failure'){3}else{0}};RemoveTask={param($s) $counts.Remove++;if($case -eq 'remove-failure'){throw 'Remove failed'}}}
 if($case -eq 'changed-worker'){Add-Content (Join-Path $root 'worker.ps1') 'changed'}
 if($case -eq 'duplicate-claim'){Write-MsiTraceRecord (Join-Path $root 'finish-claimed.json') @{Existing=$true}}
 $refused=$false;try{Invoke-MsiTraceFinish $root $ops}catch{$refused=$true}
 if($case -in @('same-boot','changed-worker','changed-task','duplicate-claim')){
  if(!$refused -or $counts.Stop -or $counts.Cancel -or $counts.Remove){throw ('Unsafe refusal: '+$case)}
 }else{
  if($refused -or $counts.Stop -ne 1 -or $counts.Remove -ne 1){throw ('Lifecycle failed: '+$case)}
  $result=Get-Content (Join-Path $root 'worker-result.json') -Raw|ConvertFrom-Json
  if($case -eq 'success' -and ($result.Error -or !$result.TraceBytes -or !$result.OwnedTaskRemoved)){throw 'Success evidence missing'}
  if($case -ne 'success' -and !$result.Error){throw 'Error was hidden'}
  if($case -in @('stop-failure','cancel-failure') -and $counts.Cancel -ne 1){throw 'Owned cancellation not attempted'}
  $before=$counts.Stop;$again=$false;try{Invoke-MsiTraceFinish $root $ops}catch{$again=$true}
  if(!$again -or $counts.Stop -ne $before){throw 'Worker repeated'}
 }
}
. (Join-Path $PSScriptRoot 'christian-boot-trace.ps1')
$stateDir=Join-Path $base 'cli';[void][IO.Directory]::CreateDirectory($stateDir)
function Start-Process {param($FilePath,$ArgumentList,$WindowStyle,[switch]$PassThru,[switch]$Wait,$RedirectStandardOutput,$RedirectStandardError)
 if($ArgumentList -cne '"-boottrace" "-cancelboot" "-instancename" "MsiDisplayaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' -or $WindowStyle -ne 'Hidden'){throw 'CLI isolation/quoting failed'}
 [pscustomobject]@{ExitCode=0}
}
if((Invoke-TraceWpr @('-boottrace','-cancelboot','-instancename',('MsiDisplay'+('a'*32))) 'fixture') -ne 0){throw 'CLI result failed'}
function Set-Acl {param($LiteralPath,$AclObject)}
function Copy-Item {param([AllowEmptyString()][string]$LiteralPath,$Destination) if(!$LiteralPath){$LiteralPath=Join-Path $PSScriptRoot 'christian-boot-trace.ps1'};[IO.File]::Copy($LiteralPath,$Destination)}
function Get-PSDrive {param($Name) [pscustomobject]@{Free=4GB}}
function Protect-TraceFile {param($Path) if(!$Path.StartsWith($stateDir)){throw 'Protected file outside state'};$protectedFiles.Add([IO.Path]::GetFileName($Path))}
function Get-CimInstance {param($ClassName) [pscustomobject]@{LastBootUpTime=[datetime]::Parse('2026-11-02T00:12:44Z')}}
function Invoke-WebRequest {param($Uri,[switch]$UseBasicParsing,$OutFile) [IO.File]::Copy((Join-Path $PSScriptRoot ([IO.Path]::GetFileName($OutFile))),$OutFile)}
function Get-ScheduledTask {param($TaskName,$ErrorAction) $taskMock}
function New-ScheduledTaskTrigger {param([switch]$AtStartup) [pscustomobject]@{Delay=$null}}
function New-ScheduledTaskSettingsSet {param($ExecutionTimeLimit,$MultipleInstances,[switch]$StartWhenAvailable,[switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries)
 if($ExecutionTimeLimit.TotalMinutes -ne 5 -or $MultipleInstances -ne 'IgnoreNew'){throw 'Unbounded task settings'};[pscustomobject]@{Valid=$true}
}
function New-ScheduledTaskAction {param($Execute,$Argument) [pscustomobject]@{Execute=$Execute;Arguments=$Argument}}
function Register-ScheduledTask {param($TaskName,$Action,$Trigger,$Settings,$User,$RunLevel)
 if($Trigger.Delay -ne 'PT30S' -or $User -ne 'SYSTEM' -or $RunLevel -ne 'Highest'){throw 'Startup task policy differs'}
 $script:taskMock=[pscustomobject]@{Actions=@($Action)}
}
function Unregister-ScheduledTask {param($TaskName,$Confirm) $script:taskMock=$null;$calls.Removed++}
function Invoke-TraceWpr {param($Arguments,$Prefix)
 if($Arguments[-2] -ne '-instancename' -or $Arguments[-1] -cnotmatch '^MsiDisplay[0-9a-f]{32}$'){throw 'Unowned WPR instance'}
 if($Prefix -eq 'prepare'){$calls.Prepare++;if($scenario -eq 'prepare-failure'){2}else{0}}else{$calls.Cancel++;0}
}
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'christian-boot-trace.ps1'),[ref]$null,[ref]$null)
$block=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item1.Extent.Text -ceq "`$Mode -eq 'Prepare'"},$true))
if($block.Count -ne 1){throw 'Could not select actual prepare block'}
$body=$block[0].Clauses[0].Item2.Extent.Text;$prepare=[scriptblock]::Create($body.Substring(1,$body.Length-2))
foreach($scenario in @('prepare-success','prepare-failure')){
 $stateDir=Join-Path $base $scenario;$taskMock=$null;$calls=[pscustomobject]@{Prepare=0;Cancel=0;Removed=0};$protectedFiles=[Collections.Generic.List[string]]::new();$AcceptTraceSetup=$true
 $failed=$false;$why=$null;try{& $prepare}catch{$failed=$true;$why=$_.Exception.Message}
 if($scenario -eq 'prepare-success'){
  if($failed -or $calls.Prepare -ne 1 -or $calls.Cancel -or !$taskMock){throw ('Preparation success failed: '+$why)}
 }else{if(!$failed -or $calls.Cancel -ne 1 -or $calls.Removed -ne 1 -or $taskMock){throw 'Preparation failure did not clean up owned recorder/task'}}
 if($protectedFiles.Count -ne 4 -or !(Test-Path (Join-Path $stateDir 'state.json'))){throw 'Protected ownership/state preparation failed'}
}
'PASS eight worker lifecycle/refusal cases, no repeat, isolated WPR arguments; WPR/task operations mocked, no boot trace enabled'
'PASS actual preparation block: protected payload/state, isolated startup task, failed-WPR cleanup; OS operations mocked'
