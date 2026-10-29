param([Parameter(Mandatory)][string]$StateDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'shared-esp-firmware-lib.ps1')
$s=Get-Content (Join-Path $StateDirectory 'firmware-backup.json') -Raw | ConvertFrom-Json
if($s.Schema -ne 'shared-esp-audit-once-v1' -or $s.OptionName -cne 'Boot7E00' -or $s.OptionNumber -ne 32256){throw 'Unexpected backup'}
Add-Type -Path (Join-Path $PSScriptRoot 'shared-esp-firmware-native.cs')
$scope=[SharedEspFirmware.Native]::EnablePrivilege()
try {
 $read={param($name) $v=[SharedEspFirmware.Native]::Read($name);if($v){ConvertTo-FirmwareValue $v.Data $v.Attributes}}
 $order=& $read 'BootOrder'
 [byte[]]$old=[Convert]::FromBase64String($s.BootOrder.DataBase64)
 [byte[]]$now=[Convert]::FromBase64String($order.DataBase64)
 if($order.Attributes -ne 7 -or $now.Length -lt $old.Length -or $now.Length%2){throw 'Unexpected order'}
 for($i=0;$i -lt $old.Length;$i++){if($now[$i] -ne $old[$i]){throw 'Original order prefix changed'}}
 Assert-SharedEspFirmwareSnapshot ([pscustomobject]@{BootOrder=$order;BootEntries=$s.BootEntries}) $read
 $entries=@();$names=@()
 for($i=0;$i -lt $now.Length;$i+=2){$name='Boot{0:X4}' -f [BitConverter]::ToUInt16($now,$i);if($name -eq $s.OptionName -or $name -in $names){throw 'Referenced temporary or duplicate option'};$names+=$name;$v=& $read $name;if(!$v){throw 'Missing entry'};$entries+=,[pscustomobject]@{Name=$name;Value=$v}}
 if($null -ne (& $read 'BootNext')){throw 'BootNext is pending'}
 if(!(Test-FirmwareValueEqual (& $read $s.OptionName) $s.Option)){throw 'Temporary entry changed'}
 [ordered]@{read_only=$true;cleanup_candidate=$true;preserved_entries=$names;temporary_option=$s.OptionName;boot_next_clear=$true;original_prefix_matches=$true;firmware_writes=0} | ConvertTo-Json -Depth 4
}finally{$scope.Dispose()}
