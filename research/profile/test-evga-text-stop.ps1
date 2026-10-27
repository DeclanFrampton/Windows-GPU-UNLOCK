param([string]$Clang='clang',[string]$LldLink='lld-link')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $repo
try {
 $out='internal-boot/boot/build/evga-text-stop';New-Item -ItemType Directory -Force $out | Out-Null
 foreach($source in @('internal-boot/boot/test_evga_text_stop.c','internal-boot/efi_runtime.c')) {
  $obj="$out/"+[IO.Path]::GetFileNameWithoutExtension($source)+'.host.obj'
  & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c $source -o $obj
  if($LASTEXITCODE -ne 0){throw "Host compile failed: $source"}
 }
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/test.exe" "$out/test_evga_text_stop.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Host link failed'}
 & "./$out/test.exe"
 if($LASTEXITCODE -ne 0){throw "Host scenario failed: $LASTEXITCODE"}
 '18 host checkpoints passed (mock protocols, mock hashes and mock Stop; no captured firmware executed).'
} finally {Pop-Location}
