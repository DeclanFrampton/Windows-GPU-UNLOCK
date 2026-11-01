# GPL-2.0-only. Default: profile-less read-only USB probe for a new machine.
# -MsiUnlock explicitly links the attended, write-enabled MSI transaction instead.
# The probe records every NVIDIA display controller, the console/driver graph, the 1 MiB PROM
# (PROM.BIN) and loaded driver images (IMGnn.BIN) to the stick it booted from, then starts
# Windows. It compiles only as a diagnostic build: no unlock code, GPU writes, driver release,
# DMA or firmware variable writes in default mode. MsiOneChildTest explicitly
# permits one text-child removal after fresh guards. Builds files only.
param([Parameter(Mandatory)][guid]$WindowsEspGuid,[string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python',
      [ValidateRange(1,255)][int]$TargetBus=1,[switch]$MsiRuntimeAudit,[switch]$MsiZeroChildTest,[switch]$MsiMembershipAudit,[switch]$MsiOneChildTest,[switch]$MsiVirtualTextTest,[switch]$MsiGraphicsTest,[switch]$MsiEdidTest,[switch]$MsiNvidiaRelease,[switch]$MsiColdProbe,[switch]$MsiColdFullProm,[switch]$MsiAssetsDma,[switch]$MsiAdmission,[switch]$MsiUnlock)
$ErrorActionPreference='Stop'
if($MsiZeroChildTest -and !$MsiRuntimeAudit){throw 'Zero-child test requires the exact MSI runtime audit'}
if($MsiMembershipAudit -and (!$MsiRuntimeAudit -or $MsiZeroChildTest)){throw 'Membership audit requires identity audit and excludes method calls'}
if($MsiOneChildTest -and (!$MsiMembershipAudit -or !$MsiRuntimeAudit -or $MsiZeroChildTest)){throw 'One-child test requires identity/membership audit and excludes zero-child mode'}
if($MsiVirtualTextTest -and !$MsiOneChildTest){throw 'Virtual renderer test requires one-child removal'}
if($MsiGraphicsTest -and !$MsiVirtualTextTest){throw 'Graphics test requires both text removal stages'}
if($MsiEdidTest -and !$MsiGraphicsTest){throw 'EDID test requires graphics membership removal'}
if($MsiNvidiaRelease -and !$MsiEdidTest){throw 'NVIDIA release requires the complete consumer sequence'}
if($MsiColdProbe -and !$MsiNvidiaRelease){throw 'Cold probe requires verified child/parent release'}
if($MsiColdFullProm -and !$MsiColdProbe){throw 'Full cold PROM requires cold probe'}
if($MsiAssetsDma -and !$MsiColdFullProm){throw 'Assets and DMA qualification requires the full cold PROM stage'}
if($MsiAdmission -and !$MsiAssetsDma){throw 'Exact admission requires payload and mapping qualification'}
if($MsiUnlock -and !$MsiAdmission){throw 'Unlock requires the exact MSI admission and prior stages'}
if($MsiUnlock -and $TargetBus -ne 1){throw 'MSI write profile is pinned to bus 1'}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$boot=Join-Path $repo 'internal-boot/boot'
function GuidC([guid]$Value){
 $b=$Value.ToByteArray();$tail=($b[8..15] | ForEach-Object {'0x{0:x2}' -f $_}) -join ','
 return ('{{0x{0:x8},0x{1:x4},0x{2:x4},{{{3}}}}}' -f [BitConverter]::ToUInt32($b,0),[BitConverter]::ToUInt16($b,4),[BitConverter]::ToUInt16($b,6),$tail)
}
$windows=@(Get-Partition | Where-Object {$_.Guid -and [guid]$_.Guid -eq $WindowsEspGuid})
if($windows.Count -ne 1 -or !$windows[0].IsSystem){throw 'WindowsEspGuid must identify the current system EFI partition'}
# Same local USB configuration as build-usb.ps1, so the two builds share it.
$config=Join-Path $boot 'platform-config.h';$marker='/* Local USB configuration (build-usb.ps1). Internal partition unused under GU_USB_MEDIA. */'
if((Test-Path -LiteralPath $config) -and (Get-Content -LiteralPath $config -TotalCount 1) -ne $marker){throw 'platform-config.h belongs to an internal Configure.ps1 setup; move it aside before a USB build'}
@($marker,('#define GU_INTERNAL_PARTITION_INITIALIZER '+(GuidC ([guid]::Empty))),('#define GU_WINDOWS_PARTITION_INITIALIZER '+(GuidC $WindowsEspGuid))) | Set-Content -LiteralPath $config -Encoding ascii
$generated=Join-Path $boot 'generated.h'
if(!(Test-Path -LiteralPath $generated)){'/* Observation build: GU_DIAGNOSTIC_ONLY excludes all unlock loading. */' | Set-Content -LiteralPath $generated -Encoding ascii}
Push-Location -LiteralPath $boot
try {
 $out=if($MsiRuntimeAudit){'build/msi-runtime-audit'}else{'build/probe-generic'}
 New-Item -ItemType Directory -Path $out -Force | Out-Null
 $sources=@('handoff.c','diagnostic.c','../efi_runtime.c','probe.c','../unlock/sha256.c')
 if($MsiAdmission){$sources+='../unlock/checks.c'}
 if($MsiUnlock){$sources=@($sources | Where-Object {$_ -ne '../efi_runtime.c'})+@('../unlock/runtime.c','../unlock/format.c','../unlock/port.c','../unlock/compat.c','../unlock/msi-transaction.c','../unlock/vendor/unlock_610.c','../unlock/vendor/prep_610.c','../unlock/vendor/layout_610.c','../unlock/vendor/vbios_610.c','../unlock/vendor/gfw_eval.c')}
 $defines=@('-DGU_DIAGNOSTIC_ONLY','-DGU_DIAGNOSTIC_PROBE','-DGU_PROBE_GENERIC','-DGU_USB_PROBE')
 if($MsiRuntimeAudit){$defines+='-DGU_MSI_RUNTIME_AUDIT'}
 if($MsiZeroChildTest){$defines+='-DGU_MSI_ZERO_CHILD_TEST'}
 if($MsiMembershipAudit){$defines+='-DGU_MSI_MEMBERSHIP_AUDIT'}
 if($MsiOneChildTest){$defines+='-DGU_MSI_ONE_CHILD_TEST'}
 if($MsiVirtualTextTest){$defines+='-DGU_MSI_VIRTUAL_TEXT_TEST'}
 if($MsiGraphicsTest){$defines+='-DGU_MSI_GRAPHICS_TEST'}
 if($MsiEdidTest){$defines+='-DGU_MSI_EDID_TEST'}
 if($MsiNvidiaRelease){$defines+='-DGU_MSI_NVIDIA_RELEASE'}
 if($MsiColdProbe){$defines+='-DGU_MSI_COLD_PROBE'}
 if($MsiColdFullProm){$defines+='-DGU_MSI_COLD_FULL_PROM'}
 if($MsiAssetsDma){$defines+='-DGU_MSI_ASSETS_DMA'}
 if($MsiAdmission){$defines+='-DGU_MSI_ADMISSION'}
 if($MsiUnlock){$defines+=@('-DGU_MSI_UNLOCK','-DGU_MSI_TRANSACTION_DEVELOPMENT','-DGU_PROFILE_MSI_H510_3090','-DGU_EXPERIMENTAL_3090','-DGU_ENTRY_LATCHED_SS1_FULL','-DGU_UEFI_PORT','-D__KERNEL__')}
 $busMode='auto'
 if($PSBoundParameters.ContainsKey('TargetBus')){
  $defines+=('-DGU_PROBE_BUS=0x{0:x}U' -f $TargetBus);$busMode='explicit'
 } else {$defines+='-DGU_PROBE_AUTO_BUS'}
 $objects=@();$compilation=@()
 foreach($source in $sources) {
  $obj="$out/"+[IO.Path]::GetFileNameWithoutExtension($source)+'.obj'
  $sourceDefines=$defines
  if($MsiUnlock -and $source -eq 'probe.c'){
   # Keep the generic capture object inside its existing read-only compile guards.
   $sourceDefines=@($defines | Where-Object {$_ -notin @('-DGU_MSI_UNLOCK','-DGU_MSI_TRANSACTION_DEVELOPMENT','-DGU_PROFILE_MSI_H510_3090','-DGU_EXPERIMENTAL_3090','-DGU_ENTRY_LATCHED_SS1_FULL','-DGU_UEFI_PORT','-D__KERNEL__')})
  }
  $compilation+=[ordered]@{Source=$source;Defines=$sourceDefines}
  & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -mno-red-zone -fshort-wchar -Os -Wall -Wextra -Werror -Wno-unused-parameter @sourceDefines -I ../unlock/compat -I ../../deps/edk2/MdePkg/Include -I ../../deps/edk2/MdePkg/Include/X64 -c $source -o $obj
  if($LASTEXITCODE -ne 0){throw "Compile failed: $source"}
  $objects+=$obj
 }
 & $LldLink /nologo /nodefaultlib /subsystem:efi_application /entry:efi_main /machine:x64 /base:0 /dynamicbase /nxcompat /timestamp:0 /opt:ref /opt:icf "/map:$out/PROBE.map" "/out:$out/BOOTX64.EFI" @objects
 if($LASTEXITCODE -ne 0){throw 'Probe link failed'}
 & $Python -I ../unlock/verify_pe.py "$out/BOOTX64.EFI" "$out/PROBE.map" --output "$out/pe-verification.json"
 if($LASTEXITCODE -ne 0){throw 'Probe PE verification failed'}
 $manifestInputs=$sources+@('diagnostic.h','media.h','probe.h','../unlock/machine-profile.h','../unlock/gpu-family.h','../unlock/firmware-profile.h')
 if($MsiRuntimeAudit){$manifestInputs+='msi-runtime-audit.h'}
 if($MsiEdidTest){$manifestInputs+='msi-edid-audit.h'}
 if($MsiNvidiaRelease){$manifestInputs+='msi-nvidia-release.h'}
 if($MsiColdProbe){$manifestInputs+='msi-cold-probe.h'}
 if($MsiAssetsDma){$manifestInputs+=@('msi-assets.h','msi-dma-probe.h','../unlock/asset-reader.h')}
 if($MsiAdmission){$manifestInputs+=@('../unlock/msi-admission.h','../unlock/checks.h')}
 if($MsiUnlock){$manifestInputs+=@('msi-transaction-graph.h','../unlock/msi-transaction.h','../unlock/port.h','../unlock/compat/compat.h','../unlock/assets.json')+@(Get-ChildItem '../unlock','../../deps/edk2/MdePkg/Include' -Filter '*.h' -File -Recurse | ForEach-Object {Resolve-Path -Relative $_.FullName})}
 [ordered]@{Mode=$(if($MsiUnlock){'msi-attended-experimental-unlock'}elseif($MsiNvidiaRelease){'msi-nvidia-child-parent-release-then-windows-usb'}elseif($MsiOneChildTest){'msi-one-child-removal-then-windows-usb'}else{'generic-read-only-probe-then-windows-usb'});MsiRuntimeAudit=[bool]$MsiRuntimeAudit;MsiZeroChildTest=[bool]$MsiZeroChildTest;MsiMembershipAudit=[bool]$MsiMembershipAudit;MsiOneChildTest=[bool]$MsiOneChildTest;MsiVirtualTextTest=[bool]$MsiVirtualTextTest;MsiGraphicsTest=[bool]$MsiGraphicsTest;CallsDriverStop=([bool]$MsiZeroChildTest -or [bool]$MsiOneChildTest);CanUnlock=[bool]$MsiUnlock;CanDetach=[bool]$MsiOneChildTest;WritesFirmwareVariables=$false;HardwareTested=$false;Defines=$defines;Compilation=$compilation
  MsiEdidTest=[bool]$MsiEdidTest;MsiNvidiaRelease=[bool]$MsiNvidiaRelease;NvidiaStopCalled=[bool]$MsiNvidiaRelease
  MsiColdProbe=[bool]$MsiColdProbe;MsiColdFullProm=[bool]$MsiColdFullProm;MsiAssetsDma=[bool]$MsiAssetsDma;DmaMappingQualification=[bool]$MsiAssetsDma;MsiAdmission=[bool]$MsiAdmission;MsiUnlock=[bool]$MsiUnlock;ColdReadCountExcludesTransaction=[bool]$MsiUnlock;CaptureObjectReadOnly=$true;WindowsEspGuid=$WindowsEspGuid.ToString();ColdMmioReads=$(if($MsiAdmission){262171}elseif($MsiColdFullProm){262162}elseif($MsiColdProbe){146}else{0});PciMemoryEnableDisable=[bool]$MsiColdProbe
  ProbeBusMode=$busMode;TargetBus=$(if($busMode -eq 'explicit'){$TargetBus}else{$null})
  EfiSha256=(Get-FileHash -LiteralPath "$out/BOOTX64.EFI").Hash.ToLowerInvariant();BuiltUtc=[DateTime]::UtcNow.ToString('o')
  Sources=@($manifestInputs | ForEach-Object {[ordered]@{Path=$_;Sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}})
 } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$out/manifest.json" -Encoding utf8
 if($MsiUnlock){"Built MSI WRITE-ENABLED unlock attempt $out/BOOTX64.EFI; NOT STAGED; live unlock/recovery unproven."}
 elseif($MsiColdProbe){"Built MSI bounded cold-state read test $out/BOOTX64.EFI; hardware untested."}
 elseif($MsiNvidiaRelease){"Built MSI NVIDIA child+parent release test $out/BOOTX64.EFI; hardware untested."}
 elseif($MsiOneChildTest){"Built MSI one-child removal test $out/BOOTX64.EFI; hardware untested."}
 else{"Built generic read-only probe $out/BOOTX64.EFI; hardware untested."}
} finally {Pop-Location}
