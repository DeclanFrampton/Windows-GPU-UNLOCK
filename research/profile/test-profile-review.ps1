# Read existing local profile evidence with this pinned source's gates. Never execute
# source/scripts/binaries from ExistingRepo, rebuild, stage or access GPU/firmware.
[CmdletBinding()]
param([string]$ExistingRepo,[string]$OutputRoot,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$trustedRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $trustedRepo 'internal-boot/unlock/local-profile.ps1')
. (Join-Path $PSScriptRoot 'collection-host.ps1')
function Get-ReviewPins([string]$Text){
 $specs=[ordered]@{
  TargetBus=@('GU_TARGET_BUS','0x([0-9a-f]{1,2})U')
  Bar0Base=@('GU_BAR0_BASE','0x([0-9a-f]{1,16})ULL')
  Bar0End=@('GU_BAR0_END','0x([0-9a-f]{1,16})ULL')
  RootPortDevice=@('GU_ROOT_PORT_DEVICE','([0-9]{1,2})U')
  RootPortFunction=@('GU_ROOT_PORT_FUNCTION','([0-9])U')
 }
 $r=[ordered]@{}
 foreach($name in $specs.Keys){
  $macro=$specs[$name][0];$pattern=$specs[$name][1]
  $rows=@([regex]::Matches($Text,('(?m)^#define '+$macro+' '+$pattern+'\r?$')))
  if($rows.Count -ne 1){throw 'Missing or ambiguous numeric profile pin.'}
  $r[$name]=$rows[0].Groups[1].Value
 }
 return $r
}
function New-ProfileReviewSummary($Hardware,$Evidence,$Pins){
 $jobs=Get-LocalExpectedJobs $Hardware.NoEdidDriver $Hardware.ConsoleAggregate
 return [ordered]@{
  Test='existing-profile-evidence-review-v1';HostEvidenceBindingsMatch=$true
  ProfileName=$Hardware.Name;TargetPci=$Hardware.TargetPci;Subsystem=$Hardware.Subsystem
  Chip=$Hardware.Chip;Memory=$Hardware.Memory;Segment=$Hardware.Segment
  NoEdidDriver=$Hardware.NoEdidDriver;ConsoleAggregate=$Hardware.ConsoleAggregate;ChildCount=$Hardware.ChildCount
  NumericHeaderPins=$Pins;HeaderSha256=$Hardware.HeaderSha256;PromSha256=$Hardware.Prom
  ProfileReportSha256=$Evidence.ProfileReportSha256;SourceTreeSha256=$Evidence.TreeSha256
  SourceInputCount=@($Evidence.Inputs).Count;ExpectedHostJobCount=$jobs.Count
  ExistingRepoCodeExecuted=$false;HostTestsRerun=$false;CaptureFilesChanged=$false
  HardwareIndependentlyVerified=$false;RecoveryVerified=$false;WriteEligible=$false
 }
}
if($SelfTest){
 $dir=Join-Path ([IO.Path]::GetTempPath()) ('profile-review-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path (Join-Path $dir 'internal-boot/unlock')|Out-Null
 $text=@(
 '#define GU_LOCAL_PROFILE_GENERATOR 1',
 '#define GU_PROFILE_NAME "LOCAL-220410de-87b31043-aaaaaaaa"',
 '#define GU_BOARD_ID 0x220410deU','#define GU_BOARD_SUBSYSTEM 0x87b31043U',
 '#define GU_CHIP_ID 0xb72000a1U','#define GU_DEVICE_MEMORY_SIZE 0x6000U',
 ('#define GU_PROM_SHA256 "'+('a'*64)+'"'),
 '#define GU_NO_EDID_DRIVER 0','#define GU_TARGET_SEGMENT 0x0U',
 '#define GU_LOCAL_CONSOLE_AGGREGATE 0','#define GU_LOCAL_CHILD_COUNT 1',
 '#define GU_TARGET_BUS 0x1U','#define GU_BAR0_BASE 0xf4000000ULL',
 '#define GU_BAR0_END 0xf4ffffffULL','#define GU_ROOT_PORT_DEVICE 1U',
 '#define GU_ROOT_PORT_FUNCTION 0U','/* PRIVATE-LOCAL-PATH */') -join ([string][char]10)
 [IO.File]::WriteAllText((Join-Path $dir 'internal-boot/unlock/profile-local.h'),$text)
 $hw=Get-LocalProfile $dir;$pins=Get-ReviewPins $text
 $e=[pscustomobject]@{ProfileReportSha256=('b'*64);TreeSha256=('c'*64);Inputs=@(1,2)}
 $r=New-ProfileReviewSummary $hw $e $pins
 if($r.ExpectedHostJobCount -ne 22 -or $r.TargetPci -cne '220410de' -or $r.WriteEligible -or $r.ExistingRepoCodeExecuted -or ($r|ConvertTo-Json -Depth 6).Contains('PRIVATE')){throw 'Profile review scope/privacy regression.'}
 $ti=$text.Replace('220410de','220310de').Replace('87b31043','161810de').Replace('0x6000U','0x5ff4U')
 [IO.File]::WriteAllText((Join-Path $dir 'internal-boot/unlock/profile-local.h'),$ti)
 $tiHardware=Get-LocalProfile $dir
 $tiSummary=New-ProfileReviewSummary $tiHardware $e (Get-ReviewPins $ti)
 if($tiSummary.TargetPci -cne '220310de' -or $tiSummary.Subsystem -cne '161810de' -or $tiSummary.Memory -cne '0x5ff4' -or $tiSummary.WriteEligible){throw '3090Ti partial-memory profile parse regression.'}
 [IO.File]::WriteAllText((Join-Path $dir 'internal-boot/unlock/profile-local.h'),$text)
 foreach($bad in @($text+[Environment]::NewLine+'#define GU_TARGET_BUS 0x2U',$text.Replace('0xf4000000ULL','PRIVATE'))){
  $refused=$false;try{Get-ReviewPins $bad|Out-Null}catch{$refused=$true};if(!$refused){throw 'Malformed/duplicate pin accepted.'}
 }
 $refused=$false;try{Assert-LocalProfileEvidence $dir|Out-Null}catch{$refused=$true}
 if(!$refused){throw 'Missing real evidence passed trusted gate.'}
 Write-Host 'PASS: real 3090/3090Ti partial-memory header parser, numeric/duplicate pin refusal, 22-job shape, missing-evidence refusal and privacy. No supplied code or firmware executed.';exit
}
try{
 if(!$ExistingRepo){$ExistingRepo=Read-Host 'Existing tested source folder containing your local profile and receipts (do not copy new files into it)'}
 $root=Get-Item -LiteralPath $ExistingRepo
 if(!$root.PSIsContainer -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $root.FullName.StartsWith('\\')){throw 'Existing source must be a regular local directory.'}
 $header=Get-Item -LiteralPath (Join-Path $root.FullName 'internal-boot/unlock/profile-local.h')
 if($header.Length -gt 64KB -or ($header.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Invalid profile header.'}
 $hw=Get-LocalProfile $root.FullName
 $e=Assert-LocalProfileEvidence $root.FullName
 $pins=Get-ReviewPins ([IO.File]::ReadAllText($header.FullName))
 $r=New-ProfileReviewSummary $hw $e $pins
 $out=New-GuCollectionOutput $OutputRoot 'GPU-Unlock-Profile-Review' $root.FullName
 $path=Join-Path $out 'profile-review.json';$r|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding utf8
 Write-Host ('Return only reviewed '+$path+'. Original source/profile/captures unchanged. No rebuild, tests, staging or boot requested.')
}catch{Write-Error 'Existing profile evidence review stopped. Keep original files unchanged; do not rerun a boot, regenerate the profile or repair source to make this pass. Report a short sanitized failure only.';exit 1}
