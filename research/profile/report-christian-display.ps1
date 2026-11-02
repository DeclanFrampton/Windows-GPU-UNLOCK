# Windows display diagnostics only. Never resets drivers, runs CUDA, touches USB or rearms EFI.
param([string]$Root='C:\GPU-Unlock',
 [ValidateSet('Ask','Login','Later','Manual','StillNone','Unknown')][string]$PictureReturned='Ask',
 [ValidateSet('Ask','Nothing','Restart','PowerOff','Cable','Monitor','Other','Unknown')][string]$RecoveryAction='Ask')
$ErrorActionPreference='Stop'
if($PictureReturned -eq 'Ask'){$PictureReturned=Read-Host 'When did the picture return? Login/Later/Manual/StillNone/Unknown'}
if($RecoveryAction -eq 'Ask'){$RecoveryAction=Read-Host 'What did you do to restore it? Nothing/Restart/PowerOff/Cable/Monitor/Other/Unknown'}
if($PictureReturned -notin @('Login','Later','Manual','StillNone','Unknown') -or $RecoveryAction -notin @('Nothing','Restart','PowerOff','Cable','Monitor','Other','Unknown')){throw 'Answer using one of the listed words; no system change made'}
$out=Join-Path $Root ('Results/christian-display-report-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
$errors=@();$boot=$null
try{$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')}catch{$errors+='Windows boot time unavailable'}
foreach($query in @(
 @{Class='Win32_VideoController';File='video.json';Fields=@('Name','Status','ConfigManagerErrorCode','DriverVersion','VideoModeDescription','CurrentHorizontalResolution','CurrentVerticalResolution','CurrentRefreshRate')},
 @{Class='Win32_DesktopMonitor';File='monitors.json';Fields=@('Name','Status','ConfigManagerErrorCode','ScreenWidth','ScreenHeight')})){
 try{@(Get-CimInstance $query.Class|Select-Object -Property $query.Fields)|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $out $query.File) -Encoding utf8}catch{$errors+=('Query unavailable: '+$query.Class)}
}
try{@(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorConnectionParams|Select-Object Active,VideoOutputTechnology)|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'connections.json') -Encoding utf8}catch{$errors+='Monitor connection query unavailable'}
try{
 $events=@(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=(Get-Date).AddHours(-2);ProviderName=@('Display','nvlddmkm','Microsoft-Windows-Kernel-PnP','Microsoft-Windows-WHEA-Logger')} -MaxEvents 300 -ErrorAction SilentlyContinue|Select-Object TimeCreated,ProviderName,Id,LevelDisplayName,Message)
 $events|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $out 'display-events.json') -Encoding utf8
}catch{$errors+='Display/system events unavailable'}
$claim=Join-Path $Root 'MSI-REARM.PREPARING';$id=$null
if(Test-Path -LiteralPath $claim){$candidate=Get-Content -LiteralPath $claim -Raw;if($candidate -cmatch '^[0-9a-f]{32}$'){$id=$candidate}}
[ordered]@{schema='christian-display-report-v1';attempt_id=$id;picture_returned=$PictureReturned;recovery_action=$RecoveryAction;current_windows_boot_utc=$boot;query_limitations=$errors;gpu_workload_run=$false;driver_reset=$false;usb_written=$false;rearmed=$false;display_return_qualified=$false}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Output ('Attach this ZIP: '+$out+'.zip')
