# Build/package only. Never stages media or writes firmware.
param([ValidateSet('SharedEsp','Usb','SeparateEsp')][string]$Layout='SharedEsp',
 [guid]$WindowsEspGuid='c36c3e86-02aa-4f76-af1b-96e327f9d1c1',[guid]$UnlockPartitionGuid=[guid]::Empty,
 [ValidateRange(8,99)][int]$AttemptSlot=10,[Parameter(Mandatory)][string]$OutputDirectory,
 [string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evga-package-lib.ps1')
$profile=Get-EvgaPackageProfile $Layout
$out=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $out){throw 'Output already exists; choose a fresh directory, never overwrite a prior attempt'}
$build=$out+'.build'
& (Join-Path $PSScriptRoot 'build-shared-esp-unlock.ps1') -WindowsEspGuid $WindowsEspGuid -UnlockPartitionGuid $UnlockPartitionGuid -AttemptSlot $AttemptSlot -PackageLayout $Layout -PackageOutput $build -Clang $Clang -LldLink $LldLink -Python $Python
[void][IO.Directory]::CreateDirectory($out)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$slug=@{SharedEsp='shared-esp';Usb='usb';SeparateEsp='separate-esp'}[$Layout]
$files=@{
 'UNLOCK.EFI'=(Join-Path $build 'BOOTX64.EFI');'profile.json'=(Join-Path $PSScriptRoot ('profiles/evga-z790-3090-'+$slug+'.json'));
 'assets.json'=(Join-Path $repo 'internal-boot/unlock/assets.json');'source-manifest.json'=(Join-Path $build 'manifest.json');
 'pe-verification.json'=(Join-Path $build 'pe-verification.json');'platform-config.h'=(Join-Path $build 'platform-config.h')
}
$inventory=@(foreach($name in @($files.Keys | Sort-Object)){
 $data=[IO.File]::ReadAllBytes($files[$name]);$target=Join-Path $out $name;Write-SharedSecondNewFile $target $data
 [ordered]@{Name=$name;Bytes=$data.Length;Sha256=(Get-EvgaPackageHash $target)}
})
$run='EVGA{0:D2}' -f $AttemptSlot
$manifest=[ordered]@{Schema='evga-attended-package-v1';ProfileId=$profile.id;Layout=$Layout;AttemptSlot=$AttemptSlot;Run=$run;WindowsEspGuid=$WindowsEspGuid.ToString();UnlockPartitionGuid=$UnlockPartitionGuid.ToString();RequiresFreshShiftG=$true;HardwareTested=$false;EfiPath=('\EFI\WindowsGPUUnlock\'+$run+'\UNLOCK.EFI');AssetsBundled=$false;Files=$inventory}
Write-EvgaPackageJson (Join-Path $out 'package.json') $manifest
$null=Assert-EvgaPackage $out
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip') -ErrorAction Stop
[ordered]@{package=$out;zip=($out+'.zip');profile=$profile.id;slot=$AttemptSlot;efi_sha256=(Get-EvgaPackageHash (Join-Path $out 'UNLOCK.EFI'));hardware_tested=$false;staged=$false;firmware_written=$false} | ConvertTo-Json
