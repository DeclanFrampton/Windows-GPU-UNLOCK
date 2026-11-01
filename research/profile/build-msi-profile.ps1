# Build a reusable, integrity-described payload. Does not install, arm, reboot or bundle NVIDIA assets.
param([Parameter(Mandatory)][string]$OutputDirectory,
 [string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'msi-package-lib.ps1')
$out=[IO.Path]::GetFullPath($OutputDirectory)
if((Test-Path -LiteralPath $out) -or (Test-Path -LiteralPath ($out+'.zip'))){throw 'Choose a fresh output directory; existing packages are preserved'}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& (Join-Path $PSScriptRoot 'build-probe.ps1') -WindowsEspGuid '3be74736-e119-47da-851a-9b1dde4d7037' -TargetBus 1 -MsiRuntimeAudit -MsiMembershipAudit -MsiOneChildTest -MsiVirtualTextTest -MsiGraphicsTest -MsiEdidTest -MsiNvidiaRelease -MsiColdProbe -MsiColdFullProm -MsiAssetsDma -MsiAdmission -MsiUnlock -Clang $Clang -LldLink $LldLink -Python $Python
$build=Join-Path $repo 'internal-boot/boot/build/msi-runtime-audit'
[void][IO.Directory]::CreateDirectory($out)
$readme=@'
# MSI attended USB payload - installer preparation

Exact MSI RTX3090 / ASUS PRIME H510M-K R2.0 only. The underlying attended USB
transaction and same-boot tensor uplift have evidence. This package has not run
on hardware. It does not qualify rearm, permanent, unattended or shared-ESP use.

No NVIDIA payloads are bundled. Supply the five hash-pinned local files and their
NVIDIA-LICENSE/NOTICE.md. Runtime graph, board, PROM and firmware pins remain required.
Do not copy this EFI onto media or create an arm marker using this preparation kit.
The existing one-shot script remains the only tested handoff; never remove its
spent/staged markers to bypass a refusal. GPU writes/DMA/reset can hang, corrupt
memory or prevent recovery. There is no generic rollback guarantee.

prepare-msi-install.ps1 in the matching source checkout verifies and copies this
package to local state for review, with a rollout plan. It never touches USB,
firmware variables, boot entries or schedules. No automatic restart or rearm.

Source: https://github.com/DeclanFrampton/Windows-GPU-UNLOCK
GPL-2.0 source hashes and per-object build flags: source-manifest.json.
'@
[IO.File]::WriteAllText((Join-Path $out 'README.md'),$readme,[Text.UTF8Encoding]::new($false))
$files=@{'UNLOCK.EFI'=(Join-Path $build 'BOOTX64.EFI');'profile.json'=(Join-Path $PSScriptRoot 'profiles/msi-h510-3090-usb.json');'assets.json'=(Join-Path $repo 'internal-boot/unlock/assets.json');'source-manifest.json'=(Join-Path $build 'manifest.json');'pe-verification.json'=(Join-Path $build 'pe-verification.json');'LICENSE'=(Join-Path $repo 'LICENSE')}
foreach($name in $files.Keys){Copy-Item -LiteralPath $files[$name] -Destination (Join-Path $out $name)}
$revision=(& git -C $repo rev-parse HEAD).Trim();if($LASTEXITCODE -ne 0){throw 'Cannot record source revision'}
$inventory=@(Get-ChildItem -LiteralPath $out -File|Sort-Object Name|ForEach-Object {[ordered]@{Name=$_.Name;Bytes=$_.Length;Sha256=(Get-MsiPackageHash $_.FullName)}})
[ordered]@{Schema='msi-attended-preparation-v1';ProfileId='msi-h510-3090-usb';Layout='Usb';SourceCommit=$revision;SourceTreeDirty=(@(& git -C $repo status --porcelain).Count -gt 0);AutomaticUnlock=$false;PermanentUnlock=$false;RearmEnabled=$false;AssetsBundled=$false;PackageHardwareTested=$false;Files=$inventory}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'package.json') -Encoding utf8
$null=Assert-MsiPackage $out
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
[ordered]@{package=$out;zip=($out+'.zip');staged=$false;armed=$false;rearm_enabled=$false;hardware_tested=$false}|ConvertTo-Json
