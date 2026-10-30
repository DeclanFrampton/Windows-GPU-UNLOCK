# GPL-2.0-only. Shared package contracts; no operations at import.
. (Join-Path $PSScriptRoot 'shared-esp-audit-stage-lib.ps1')
. (Join-Path $PSScriptRoot 'shared-esp-second-arm-lib.ps1')
function Get-EvgaPackageProfile([string]$Layout){
 $slug=@{SharedEsp='shared-esp';Usb='usb';SeparateEsp='separate-esp'}[$Layout]
 if(!$slug){throw 'Unknown layout'}
 $path=Join-Path $PSScriptRoot ('profiles/evga-z790-3090-'+$slug+'.json')
 $p=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
 if($p.schema -cne 'evga-attended-profile-v1' -or $p.layout -cne $Layout -or $p.machine_profile -cne 'GU_PROFILE_EVGA_Z790_3090' -or $p.pci_id -cne '220410de' -or $p.subsystem_id -cne '33873842' -or $p.requires_fresh_shift_g -ne $true -or $p.automatic_unlock -ne $false){throw 'Unsupported profile contract'}
 return $p
}
function Get-EvgaPackageHash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-EvgaPackageJson([string]$Path,$Value){Write-SharedSecondNewFile $Path ([Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 12)))}
function Assert-EvgaPackageResult([string]$Root,[int]$Slot,[string]$Run){
 $log=Get-AuditCheckedPath $Root @('RTX3090-UNLOCK',($Run+'.TXT')) $false
 $gate=Get-AuditCheckedPath $Root @('RTX3090-UNLOCK',($Run+'.ARMED')) $false
 $gpu=Get-AuditCheckedPath $Root @('RTX3090-UNLOCK',("EVGA-UNLOCK$Slot.ARMED")) $false
 if((Get-Item -LiteralPath $log).Length -gt 9MB -or (Get-Item -LiteralPath $gate).Length -ne 512 -or (Get-Item -LiteralPath $gpu).Length -gt 1024){throw 'Unexpected prior evidence size'}
 $prefix=[Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($gate))
 if(!$prefix.StartsWith("STARTED $Run - DO NOT REPEAT`r`n",[StringComparison]::Ordinal)){throw 'Prior gate did not record execution'}
 $text=[IO.File]::ReadAllText($log)
 foreach($event in @(('evga-unlock-slot-{0:D2}' -f $Slot),'evga-unlock-transaction-return','evga-unlock-assets-released','evga-unlock-close-return','evga-text-stop-ready-windows')){if(!$text.Contains($event+' status=0x0000000000000000')){throw "Prior attempt incomplete: $event"}}
 if(([regex]::Matches($text,'(?m)^capture-complete=1\r?$')).Count -lt 2){throw 'Prior attempt lacks two captures'}
 return [pscustomobject]@{Log=$log;LogSha256=(Get-EvgaPackageHash $log);GateSha256=(Get-EvgaPackageHash $gate);GpuMarkerSha256=(Get-EvgaPackageHash $gpu)}
}
function Assert-EvgaPackage([string]$Directory){
 $m=Get-Content -LiteralPath (Join-Path $Directory 'package.json') -Raw | ConvertFrom-Json
 $p=Get-EvgaPackageProfile $m.Layout
 if($m.Schema -cne 'evga-attended-package-v1' -or $m.ProfileId -cne $p.id -or $m.AttemptSlot -lt 8 -or $m.AttemptSlot -gt 99 -or $m.Run -cne ('EVGA{0:D2}' -f $m.AttemptSlot) -or $m.RequiresFreshShiftG -ne $true -or $m.HardwareTested -ne $false){throw 'Invalid package identity'}
 foreach($file in $m.Files){
  if($file.Name -cnotin @('UNLOCK.EFI','profile.json','assets.json','source-manifest.json','pe-verification.json','platform-config.h')){throw 'Unknown package file'}
  $path=Get-AuditCheckedPath $Directory @($file.Name) $false
  if((Get-Item -LiteralPath $path).Length -ne $file.Bytes -or (Get-EvgaPackageHash $path) -cne $file.Sha256){throw 'Package file changed'}
 }
 if($m.Files.Count -ne 6 -or @($m.Files.Name | Select-Object -Unique).Count -ne 6){throw 'Incomplete package inventory'}
 $pe=Get-Content -LiteralPath (Join-Path $Directory 'pe-verification.json') -Raw | ConvertFrom-Json
 $exe=@($m.Files | Where-Object Name -CEQ 'UNLOCK.EFI')[0]
 if($pe.sha256 -cne $exe.Sha256 -or $pe.machine -cne 'AMD64' -or $pe.subsystem -ne 10 -or $pe.imports -ne 0 -or $pe.iat -ne 0 -or $pe.delay_imports -ne 0 -or !$pe.nx -or !$pe.dynamic_base){throw 'PE verification differs'}
 return $m
}
