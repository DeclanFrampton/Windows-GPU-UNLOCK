# Build only. Downloads a pinned source snapshot into a new folder; never stages media.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$revision='2bb452f27ccd56f61e591d5a4a6c0431df96403e'
$clang=Get-Command clang -ErrorAction SilentlyContinue
$lld=Get-Command lld-link -ErrorAction SilentlyContinue
if(!$clang -and (Test-Path 'C:\Program Files\LLVM\bin\clang.exe')){$clang=Get-Command 'C:\Program Files\LLVM\bin\clang.exe'}
if(!$lld -and (Test-Path 'C:\Program Files\LLVM\bin\lld-link.exe')){$lld=Get-Command 'C:\Program Files\LLVM\bin\lld-link.exe'}
if(!$clang -or !$lld){throw 'LLVM compiler/linker not found. Send this error; install nothing yet.'}
$python=Get-Command python -ErrorAction Stop
$work=Join-Path $Root ('Builds/msi-audit-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($work)
$archive=Join-Path $work 'source.zip'
Invoke-WebRequest -UseBasicParsing ('https://github.com/DeclanFrampton/Windows-GPU-UNLOCK/archive/'+$revision+'.zip') -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $work
$repo=Join-Path $work ('Windows-GPU-UNLOCK-'+$revision)
& (Join-Path $repo 'research/profile/build-probe.ps1') -WindowsEspGuid '3be74736-e119-47da-851a-9b1dde4d7037' -MsiRuntimeAudit -Clang $clang.Source -LldLink $lld.Source -Python $python.Source
$built=Join-Path $repo 'internal-boot/boot/build/msi-runtime-audit'
$m=Get-Content -LiteralPath (Join-Path $built 'manifest.json') -Raw | ConvertFrom-Json
if(!$m.MsiRuntimeAudit -or $m.CanUnlock -or $m.CanDetach -or $m.WritesFirmwareVariables){throw 'Unexpected build mode; do not use image'}
$out=Join-Path $Root ('Results/christian-audit-build-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
foreach($file in @('BOOTX64.EFI','manifest.json','pe-verification.json')){Copy-Item -LiteralPath (Join-Path $built $file) -Destination (Join-Path $out $file)}
[IO.File]::WriteAllText((Join-Path $out 'source-revision.txt'),$revision,[Text.UTF8Encoding]::new($false))
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
[ordered]@{evidence_zip=$zip;efi_sha256=$m.EfiSha256;staged=$false;firmware_written=$false;gpu_accessed=$false;next='Attach this ZIP. Do not copy EFI to USB or reboot; this step only builds it for review.'} | ConvertTo-Json
