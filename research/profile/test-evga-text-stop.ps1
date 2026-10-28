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
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/nvidia.host.obj"
 if($LASTEXITCODE -ne 0){throw 'NVIDIA audit host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/nvidia-test.exe" "$out/nvidia.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'NVIDIA audit host link failed'}
 & "./$out/nvidia-test.exe"
 if($LASTEXITCODE -ne 0){throw "NVIDIA audit scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -DGU_EVGA_STOP_NVIDIA_CHILDREN -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/nvidia-children.host.obj"
 if($LASTEXITCODE -ne 0){throw 'NVIDIA children host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/nvidia-children-test.exe" "$out/nvidia-children.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'NVIDIA children host link failed'}
 & "./$out/nvidia-children-test.exe"
 if($LASTEXITCODE -ne 0){throw "NVIDIA children scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -DGU_EVGA_STOP_NVIDIA_CHILDREN -DGU_EVGA_STOP_NVIDIA_PARENT -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/nvidia-parent.host.obj"
 if($LASTEXITCODE -ne 0){throw 'NVIDIA parent host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/nvidia-parent-test.exe" "$out/nvidia-parent.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'NVIDIA parent host link failed'}
 & "./$out/nvidia-parent-test.exe"
 if($LASTEXITCODE -ne 0){throw "NVIDIA parent scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -DGU_EVGA_STOP_NVIDIA_CHILDREN -DGU_EVGA_STOP_NVIDIA_PARENT -DGU_EVGA_PROBE_DECODE -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/decode-probe.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Decode probe host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/decode-probe-test.exe" "$out/decode-probe.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Decode probe host link failed'}
 & "./$out/decode-probe-test.exe"
 if($LASTEXITCODE -ne 0){throw "Decode probe scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -DGU_EVGA_STOP_NVIDIA_CHILDREN -DGU_EVGA_STOP_NVIDIA_PARENT -DGU_EVGA_PROBE_DECODE -DGU_EVGA_PROBE_STATE -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/state-probe.host.obj"
 if($LASTEXITCODE -ne 0){throw 'State probe host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/state-probe-test.exe" "$out/state-probe.host.obj" "$out/efi_runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'State probe host link failed'}
 & "./$out/state-probe-test.exe"
 if($LASTEXITCODE -ne 0){throw "State probe scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -O1 -Wall -Wextra -Werror -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/unlock/checks.c -o "$out/shared-checks.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Shared config checks compile failed'}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -DGU_EVGA_STOP_NVIDIA_CHILDREN -DGU_EVGA_STOP_NVIDIA_PARENT -DGU_EVGA_PROBE_DECODE -DGU_EVGA_PROBE_STATE -DGU_EVGA_PROBE_PLATFORM -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/platform-probe.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Platform probe host compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/platform-probe-test.exe" "$out/platform-probe.host.obj" "$out/efi_runtime.host.obj" "$out/shared-checks.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Platform probe host link failed'}
 & "./$out/platform-probe-test.exe"
 if($LASTEXITCODE -ne 0){throw "Platform probe scenario failed: $LASTEXITCODE"}
 & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -O1 -Wall -Wextra -Werror -DGU_EVGA_RELEASE_TEXT -DGU_EVGA_RELEASE_GRAPHICS -DGU_EVGA_RELEASE_EDID -DGU_EVGA_RELEASE_EDID_SIBLINGS -DGU_EVGA_AUDIT_NVIDIA -DGU_EVGA_STOP_NVIDIA_CHILDREN -DGU_EVGA_STOP_NVIDIA_PARENT -DGU_EVGA_PROBE_DECODE -DGU_EVGA_PROBE_STATE -DGU_EVGA_PROBE_PLATFORM -DGU_EVGA_PROBE_RESOURCES -I deps/edk2/MdePkg/Include -I deps/edk2/MdePkg/Include/X64 -c internal-boot/boot/test_evga_text_stop.c -o "$out/resource-integration.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Resource integration compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/resource-integration-test.exe" "$out/resource-integration.host.obj" "$out/efi_runtime.host.obj" "$out/shared-checks.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Resource integration link failed'}
 & "./$out/resource-integration-test.exe"
 if($LASTEXITCODE -ne 0){throw "Resource integration failed: $LASTEXITCODE"}
 '6 resource integration checkpoints passed (mock acquisition callback).'
 $resourceFlags=@('-target','x86_64-pc-windows-msvc','-std=c11','-ffreestanding','-fno-builtin','-fno-stack-protector','-O1','-Wall','-Wextra','-Werror','-I','deps/edk2/MdePkg/Include','-I','deps/edk2/MdePkg/Include/X64')
 & $Clang @resourceFlags -DGU_HEADLESS_RESEARCH -DGU_OWNERSHIP_CLAIM_ONLY -c internal-boot/unlock/ownership.c -o "$out/ownership.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Shared ownership compile failed'}
 & $Clang @resourceFlags -c internal-boot/unlock/runtime.c -o "$out/resource-runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Resource runtime compile failed'}
 & $Clang @resourceFlags -c internal-boot/boot/test_evga_resources.c -o "$out/resources.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Resources test compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/resources-test.exe" "$out/resources.host.obj" "$out/ownership.host.obj" "$out/resource-runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Resources test link failed'}
 & "./$out/resources-test.exe"
 if($LASTEXITCODE -ne 0){throw "Resources scenario failed: $LASTEXITCODE"}
 & $Clang @resourceFlags -c internal-boot/unlock/sha256.c -o "$out/asset-sha.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Asset SHA compile failed'}
 & $Clang @resourceFlags -c internal-boot/boot/test_asset_reader.c -o "$out/asset-reader.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Asset reader test compile failed'}
 & $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$out/asset-reader-test.exe" "$out/asset-reader.host.obj" "$out/asset-sha.host.obj" "$out/resource-runtime.host.obj"
 if($LASTEXITCODE -ne 0){throw 'Asset reader test link failed'}
 & "./$out/asset-reader-test.exe"
 if($LASTEXITCODE -ne 0){throw "Asset reader scenario failed: $LASTEXITCODE"}
 '6 real SHA256 reader vector/refusal scenarios passed (mock EFI file/pool).'
 '13 shared asset/ownership resource scenarios passed (synthetic hash callback, no firmware executed).'
 '25 membership host checkpoints, 7 combined-release checkpoints, 8 graphics-release checkpoints, 12 EDID checkpoints, 13 sibling checkpoints, 11 NVIDIA audit checkpoints, 11 NVIDIA child checkpoints, 11 NVIDIA parent checkpoints, 8 decode-probe checkpoints, 6 state-probe checkpoints, 5 platform-probe checkpoints and 9 capture regression cases passed (mock protocols, hashes and Stop; no captured firmware executed).'
} finally {Pop-Location}
