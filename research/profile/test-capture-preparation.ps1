# GPL-2.0-only. RAM-only firmware mocks and compile-time admission tests.
param([string]$Clang='clang',[string]$VcVars)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'host.ps1')
Import-GuHostCompiler $VcVars
$boot=Join-Path $PSScriptRoot '../../internal-boot/boot'
Push-Location -LiteralPath $boot
try {
 New-Item -ItemType Directory -Path build/capture-tests/include -Force | Out-Null
 # Fallback only: an existing private configuration beside media.h wins.
 @('#define GU_INTERNAL_PARTITION_INITIALIZER {0,0,0,{0}}',
   '#define GU_WINDOWS_PARTITION_INITIALIZER {1,0,0,{0}}') | Set-Content build/capture-tests/include/platform-config.h -Encoding ascii
 $flags=@('-std=c11','-O1','-Wall','-Wextra','-Werror','-D_CRT_SECURE_NO_WARNINGS',
   '-I','build/capture-tests/include','-I','../../deps/edk2/MdePkg/Include','-I','../../deps/edk2/MdePkg/Include/X64')
 $ad104=@('-DGU_DIAGNOSTIC_ONLY','-DGU_DIAGNOSTIC_PROBE','-DGU_PROBE_GENERIC','-DGU_PROBE_AD104_MSI','-DGU_USB_MEDIA')
 & $Clang @flags -Wno-unused-function @ad104 test_probe_ad104.c probe.c ../unlock/sha256.c -o build/capture-tests/ad104.exe
 if($LASTEXITCODE -ne 0){throw 'AD104 mocks compile failed'}
 & ./build/capture-tests/ad104.exe
 if($LASTEXITCODE -ne 0){throw 'AD104 mocks failed'}
 & $Clang @flags -Wno-unused-function @ad104 -DGU_PROBE_AD104_METADATA test_probe_ad104.c probe.c ../unlock/sha256.c -o build/capture-tests/metadata.exe
 if($LASTEXITCODE -ne 0){throw 'AD104 metadata mocks compile failed'}
 & ./build/capture-tests/metadata.exe
 if($LASTEXITCODE -ne 0){throw 'AD104 metadata mocks failed'}
 & $Clang @flags -DGU_DIAGNOSTIC_ONLY -DGU_USB_PROBE test_mbr_handoff.c ../unlock/sha256.c -o build/capture-tests/mbr.exe
 if($LASTEXITCODE -ne 0){throw 'MBR mocks compile failed'}
 & ./build/capture-tests/mbr.exe
 if($LASTEXITCODE -ne 0){throw 'MBR mocks failed'}
 & $Clang @flags test_windows_media.c -o build/capture-tests/gpt.exe
 if($LASTEXITCODE -ne 0){throw 'GPT regression compile failed'}
 & ./build/capture-tests/gpt.exe
 if($LASTEXITCODE -ne 0){throw 'GPT regression failed'}
 $ErrorActionPreference='Continue'
 foreach($bad in @('-DGU_FULL_UNLOCK','-DGU_UEFI_PORT','-DGU_INTERNAL_BOOT','-DGU_HEADLESS_RESEARCH','-DGU_EXPERIMENTAL_3090','-DGU_CONSOLE_PREPARE','-DGU_AUTOMATIC_BOOT')) {
  $out=& $Clang @flags @ad104 $bad -fsyntax-only probe.c 2>&1 | Out-String
  if($LASTEXITCODE -eq 0 -or $out -notmatch 'AD104 capture is a separate read-only'){throw "AD104 compile guard failed: $bad"}
  $out=& $Clang @flags -DGU_DIAGNOSTIC_ONLY -DGU_USB_PROBE $bad -fsyntax-only test_mbr_handoff.c 2>&1 | Out-String
  if($LASTEXITCODE -eq 0 -or $out -notmatch 'MBR Windows volume selection is diagnostic-only'){throw "MBR compile guard failed: $bad"}
 }
 $out=& $Clang @flags -DGU_PROBE_AD104_MSI -fsyntax-only probe.c 2>&1 | Out-String
 if($LASTEXITCODE -eq 0 -or $out -notmatch 'AD104 capture is a separate read-only'){throw 'AD104 accepted outside diagnostic mode'}
 $out=& $Clang @flags -DGU_USB_PROBE -fsyntax-only test_mbr_handoff.c 2>&1 | Out-String
 if($LASTEXITCODE -eq 0 -or $out -notmatch 'MBR Windows volume selection is diagnostic-only'){throw 'MBR accepted outside diagnostic mode'}
 $ErrorActionPreference='Stop'
 $global:LASTEXITCODE=0
 'PASS 16 incompatible/non-diagnostic build combinations rejected'
} finally {Pop-Location}
