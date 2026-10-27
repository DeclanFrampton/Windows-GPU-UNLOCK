param([string]$Clang='clang',[string]$LldLink='lld-link')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $repo
try {
 $out='internal-boot/boot/build/evga-text-stop';New-Item -ItemType Directory -Force $out | Out-Null
 foreach($source in @('internal-boot/boot/test_evga_text_stop.c','internal-boot/boot/test_evga_gop_capture.c','internal-boot/efi_runtime.c')) {
  $obj="$out/"+[IO.Path]::GetFileNameWithoutExtension($source)+'.host.obj'
  & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c $source -o $obj
  if($LASTEXITCODE -ne 0){throw "Host compile failed: $source"}
 }
 foreach($name in @('test_evga_text_stop','test_evga_gop_capture')) {
  & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/$name.exe" "$out/$name.host.obj" "$out/efi_runtime.host.obj"
  if($LASTEXITCODE -ne 0){throw "Host link failed: $name"}
  & "./$out/$name.exe"
  if($LASTEXITCODE -ne 0){throw "Host scenario failed: $name/$LASTEXITCODE"}
 }
 '25 membership host checkpoints and 9 capture regression cases passed (mock protocols, hashes and Stop; no captured firmware executed).'
} finally {Pop-Location}
