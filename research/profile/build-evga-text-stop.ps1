# GPL-2.0-only. Compile only. Does not stage USB, change boot configuration or execute EFI.
param([Parameter(Mandatory)][guid]$WindowsEspGuid,[string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python',[switch]$ReleaseVirtualText,[switch]$ReleaseGraphics)
$ErrorActionPreference='Stop'
if($ReleaseGraphics){$ReleaseVirtualText=$true}
if($WindowsEspGuid -eq [guid]::Empty){throw 'An exact Windows ESP GUID is required'}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location (Join-Path $repo 'internal-boot/boot')
try {
 $out='build/evga-text-stop';New-Item -ItemType Directory -Force $out | Out-Null
 $b=$WindowsEspGuid.ToByteArray();$tail=($b[8..15] | ForEach-Object {'0x{0:x2}' -f $_}) -join ','
 $guidC='{{0x{0:x8},0x{1:x4},0x{2:x4},{{{3}}}}}' -f [BitConverter]::ToUInt32($b,0),[BitConverter]::ToUInt16($b,4),[BitConverter]::ToUInt16($b,6),$tail
 @('#define GU_INTERNAL_PARTITION_INITIALIZER {0,0,0,{0,0,0,0,0,0,0,0}}',('#define GU_WINDOWS_PARTITION_INITIALIZER '+$guidC)) | Set-Content "$out/platform-config.h" -Encoding ascii
 $sources=@('handoff.c','evga-text-stop.c','diagnostic.c','../efi_runtime.c','../unlock/sha256.c')
 $defines=@('-DGU_DIAGNOSTIC_ONLY','-DGU_USB_MEDIA','-DGU_EVGA_STOP_ONLY');$objects=@();if($ReleaseVirtualText){$defines+='-DGU_EVGA_RELEASE_TEXT'};if($ReleaseGraphics){$defines+='-DGU_EVGA_RELEASE_GRAPHICS'}
 foreach($source in $sources) {
  $obj="$out/"+[IO.Path]::GetFileNameWithoutExtension($source)+'.obj'
  & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -mno-red-zone -fshort-wchar -Os -Wall -Wextra -Werror @defines -I ../../deps/edk2/MdePkg/Include -I ../../deps/edk2/MdePkg/Include/X64 -c $source -o $obj
  if($LASTEXITCODE -ne 0){throw "Compile failed: $source"};$objects+=$obj
 }
 & $LldLink /nologo /nodefaultlib /subsystem:efi_application /entry:efi_main /machine:x64 /base:0 /dynamicbase /nxcompat /timestamp:0 /opt:ref /opt:icf "/map:$out/EVGA.map" "/out:$out/BOOTX64.EFI" @objects
 if($LASTEXITCODE -ne 0){throw 'Link failed'}
 & $Python -I ../unlock/verify_pe.py "$out/BOOTX64.EFI" "$out/EVGA.map" --output "$out/pe-verification.json"
 if($LASTEXITCODE -ne 0){throw 'PE verification failed'}
 [ordered]@{Mode=$(if($ReleaseGraphics){'evga3090-three-consumer-stops'}elseif($ReleaseVirtualText){'evga3090-two-text-stops'}else{'evga3090-one-text-membership-stop'});HardwareTested=$false;CanUnlock=$false;CanStopTextMembership=$true;WindowsEspGuid=$WindowsEspGuid.ToString();Staged=$false
 EfiSha256=(Get-FileHash "$out/BOOTX64.EFI" -Algorithm SHA256).Hash.ToLowerInvariant();Sources=@(($sources+@('evga-text-stop.h','media.h',"$out/platform-config.h")) | ForEach-Object {[ordered]@{Path=$_;Sha256=(Get-FileHash $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})} | ConvertTo-Json -Depth 5 | Set-Content "$out/manifest.json" -Encoding utf8
 $guide=if($ReleaseGraphics){'NEXT-GRAPHICS-RELEASE.en.md'}elseif($ReleaseVirtualText){'NEXT-TEXT-RELEASE.en.md'}else{'NEXT-EFI-TEST.en.md'}
 Write-Output "Compiled $out/BOOTX64.EFI. NOT STAGED. Read $guide for risk and staging/run instructions; no separate confirmation reply is required."
} finally {Pop-Location}
