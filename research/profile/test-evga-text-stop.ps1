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
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/release.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Combined release host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/release-test.exe" "$out/release.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Combined release host link failed'}
 & "./$out/release-test.exe"
 if($LASTEXITCODE -ne 0){throw "Combined release scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/graphics.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Graphics release host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/graphics-test.exe" "$out/graphics.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Graphics release host link failed'}
 & "./$out/graphics-test.exe"
 if($LASTEXITCODE -ne 0){throw "Graphics release scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/edid.host.obj"
 if($LASTEXITCODE -ne 0){throw 'EDID host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/edid-test.exe" "$out/edid.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'EDID host link failed'}
 & "./$out/edid-test.exe"
 if($LASTEXITCODE -ne 0){throw "EDID scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/siblings.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Sibling host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/siblings-test.exe" "$out/siblings.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Sibling host link failed'}
 & "./$out/siblings-test.exe"
 if($LASTEXITCODE -ne 0){throw "Sibling scenario failed: $LASTEXITCODE"}
 '25 membership host checkpoints, 7 combined-release checkpoints, 8 graphics-release checkpoints, 12 EDID checkpoints, 13 sibling checkpoints and 9 capture regression cases passed (mock protocols, hashes and Stop; no captured firmware executed).'
} finally {Pop-Location}
