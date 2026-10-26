# GPL-2.0-only. Optional EDID/text/GOP lifecycle switches perform attended consumer mutations.
# Default: build the profile-less read-only USB probe (-DGU_PROBE_GENERIC) for a new machine.
# The probe records every NVIDIA display controller, the console/driver graph, the 1 MiB PROM
# (PROM.BIN) and loaded driver images (IMGnn.BIN) to the stick it booted from, then starts
# Windows. It compiles only as a diagnostic build: no unlock code, GPU writes, driver release,
# DMA or firmware variable writes. Builds files only.
param([Parameter(Mandatory,ParameterSetName='Gpt')][guid]$WindowsEspGuid,
 [Parameter(Mandatory,ParameterSetName='Mbr')][switch]$WindowsMbr,
 [switch]$Ad104Msi,[switch]$Ad104Metadata,[switch]$Ad104FirmwareRom,[switch]$Ad104Resources,[switch]$Ad104Preflight,[switch]$Ad104EdidTest,[switch]$Ad104OutputObservation,[switch]$Ad104PcdCapture,[switch]$Ad104TextTest,[switch]$Ad104GopTest,[string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python')
$ErrorActionPreference='Stop'
if($Ad104Metadata -and !$Ad104Msi){throw 'Ad104Metadata requires Ad104Msi'}
if($Ad104FirmwareRom -and !$Ad104Metadata){throw 'Ad104FirmwareRom requires Ad104Metadata'}
if($Ad104Resources -and (!$Ad104Metadata -or $Ad104FirmwareRom)){throw 'Ad104Resources requires metadata mode without firmware ROM capture'}
if($Ad104Preflight -and !$Ad104Resources){throw 'Ad104Preflight requires Ad104Resources'}
if($Ad104EdidTest -and (!$Ad104Preflight -or !$WindowsMbr)){throw 'Ad104EdidTest requires Ad104Preflight and WindowsMbr'}
if($Ad104OutputObservation -and (!$Ad104Preflight -or $Ad104EdidTest)){throw 'Output observation requires preflight without EDID mutation'}
if($Ad104PcdCapture -and !$Ad104OutputObservation){throw 'PCD capture requires output observation'}
if($Ad104TextTest -and (!$Ad104PcdCapture -or !$WindowsMbr -or $Ad104EdidTest)){throw 'Text test requires PCD capture and WindowsMbr without EDID test'}
if($Ad104GopTest -and !$Ad104TextTest){throw 'GOP test requires text test'}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$boot=Join-Path $repo 'internal-boot/boot'
function GuidC([guid]$Value){
 $b=$Value.ToByteArray();$tail=($b[8..15] | ForEach-Object {'0x{0:x2}' -f $_}) -join ','
 return ('{{0x{0:x8},0x{1:x4},0x{2:x4},{{{3}}}}}' -f [BitConverter]::ToUInt32($b,0),[BitConverter]::ToUInt16($b,4),[BitConverter]::ToUInt16($b,6),$tail)
}
$mbrConfig=@()
if($WindowsMbr) {
 $windows=@(Get-Partition | Where-Object IsSystem)
 if($windows.Count -ne 1){throw 'Expected one current Windows system boot partition'}
 $part=$windows[0];$disk=Get-Disk -Number $part.DiskNumber
 if($disk.PartitionStyle -ne 'MBR' -or !$disk.Signature -or $disk.BusType -eq 'USB' -or
    $disk.LogicalSectorSize -ne 512 -or !$part.IsActive -or $part.MbrType -ne 7 -or
    !$part.Size -or $part.Offset%512 -or $part.Size%512){throw 'Unreviewed MBR boot partition geometry'}
 if((Get-ComputerInfo -Property BiosFirmwareType).BiosFirmwareType.ToString() -ne 'Uefi'){throw 'UEFI Windows boot required'}
 $volume=Get-Volume -Partition $part
 if(!$volume.Path){throw 'System boot volume path unavailable'}
 $manager=Join-Path $volume.Path 'EFI\Microsoft\Boot\bootmgfw.efi'
 $managerFile=Get-Item -LiteralPath $manager -ErrorAction Stop
 if(!$managerFile.Length -or $managerFile.Length -gt 8MB){throw 'Unexpected boot-manager size'}
 $managerHash=(Get-FileHash -LiteralPath $manager -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
 $mbrConfig=@('#ifdef GU_DIAGNOSTIC_MBR',
  ('#define GU_WINDOWS_MBR_SIGNATURE 0x{0:x8}U' -f [uint32]$disk.Signature),
  ('#define GU_WINDOWS_MBR_PARTITION {0}U' -f $part.PartitionNumber),
  ('#define GU_WINDOWS_MBR_START {0}ULL' -f [uint64]($part.Offset/512)),
  ('#define GU_WINDOWS_MBR_SIZE {0}ULL' -f [uint64]($part.Size/512)),
  ('#define GU_WINDOWS_BOOT_BYTES {0}U' -f $managerFile.Length),
  ('#define GU_WINDOWS_BOOT_SHA256 "'+$managerHash+'"'),'#endif')
 # Deliberately unused GUID in the MBR diagnostic. Never a discovered ESP GUID.
 $WindowsEspGuid=[guid]'ffffffff-ffff-ffff-ffff-ffffffffffff'
} else {
 $windows=@(Get-Partition | Where-Object {$_.Guid -and [guid]$_.Guid -eq $WindowsEspGuid})
 if($windows.Count -ne 1 -or !$windows[0].IsSystem){throw 'WindowsEspGuid must identify the current system EFI partition'}
}
# Same local USB configuration as build-usb.ps1, so the two builds share it.
$config=Join-Path $boot 'platform-config.h';$marker='/* Local USB configuration (build-usb.ps1). Internal partition unused under GU_USB_MEDIA. */'
if((Test-Path -LiteralPath $config) -and (Get-Content -LiteralPath $config -TotalCount 1) -ne $marker){throw 'platform-config.h belongs to an internal Configure.ps1 setup; move it aside before a USB build'}
(@($marker,('#define GU_INTERNAL_PARTITION_INITIALIZER '+(GuidC ([guid]::Empty))),('#define GU_WINDOWS_PARTITION_INITIALIZER '+(GuidC $WindowsEspGuid)))+$mbrConfig) | Set-Content -LiteralPath $config -Encoding ascii
$generated=Join-Path $boot 'generated.h'
if(!(Test-Path -LiteralPath $generated)){'/* Observation build: GU_DIAGNOSTIC_ONLY excludes all unlock loading. */' | Set-Content -LiteralPath $generated -Encoding ascii}
Push-Location -LiteralPath $boot
try {
 $out='build/probe-generic'
 if($Ad104Msi){$out='build/probe-ad104-msi'}
 if($Ad104Metadata){$out='build/probe-ad104-metadata'}
 if($Ad104FirmwareRom){$out='build/probe-ad104-firmrom'}
 if($Ad104Resources){$out='build/probe-ad104-resources'}
 if($Ad104Preflight){$out='build/probe-ad104-preflight'}
 if($Ad104EdidTest){$out='build/probe-ad104-edid'}
 if($Ad104OutputObservation){$out='build/probe-ad104-output'}
 if($Ad104PcdCapture){$out='build/probe-ad104-pcd'}
 if($Ad104TextTest){$out='build/probe-ad104-text'}
 if($Ad104GopTest){$out='build/probe-ad104-gop'}
 New-Item -ItemType Directory -Path $out -Force | Out-Null
 $sources=@('handoff.c','diagnostic.c','../efi_runtime.c','probe.c','../unlock/sha256.c')
 $defines=@('-DGU_DIAGNOSTIC_ONLY','-DGU_DIAGNOSTIC_PROBE','-DGU_PROBE_GENERIC','-DGU_USB_PROBE')
 if($Ad104Msi){$defines+=@('-DGU_PROBE_AD104_MSI','-DGU_USB_MEDIA')}
 if($Ad104Metadata){$defines+='-DGU_PROBE_AD104_METADATA'}
 if($Ad104FirmwareRom){$defines+='-DGU_PROBE_AD104_FIRMROM'}
 if($Ad104Resources){$defines+='-DGU_PROBE_AD104_RESOURCES'}
 if($Ad104Preflight){$defines+='-DGU_PROBE_AD104_PREFLIGHT'}
 if($Ad104EdidTest){$defines+='-DGU_AD104_EDID_TEST'}
 if($Ad104OutputObservation){$defines+='-DGU_AD104_OUTPUT_OBSERVATION'}
 if($Ad104PcdCapture){$defines+='-DGU_AD104_PCD_CAPTURE'}
 if($Ad104TextTest){$defines+='-DGU_AD104_TEXT_TEST'}
 if($Ad104GopTest){$defines+='-DGU_AD104_GOP_TEST'}
 if($WindowsMbr){$defines+='-DGU_DIAGNOSTIC_MBR';if(!$Ad104Msi){$defines+='-DGU_USB_MEDIA'}}
 $objects=@()
 foreach($source in $sources) {
  $obj="$out/"+[IO.Path]::GetFileNameWithoutExtension($source)+'.obj'
  & $Clang -target x86_64-pc-windows-msvc -std=c11 -ffreestanding -fno-builtin -fno-stack-protector -mno-red-zone -fshort-wchar -Os -Wall -Wextra -Werror @defines -I ../../deps/edk2/MdePkg/Include -I ../../deps/edk2/MdePkg/Include/X64 -c $source -o $obj
  if($LASTEXITCODE -ne 0){throw "Compile failed: $source"}
  $objects+=$obj
 }
 & $LldLink /nologo /nodefaultlib /subsystem:efi_application /entry:efi_main /machine:x64 /base:0 /dynamicbase /nxcompat /timestamp:0 /opt:ref /opt:icf "/map:$out/PROBE.map" "/out:$out/BOOTX64.EFI" @objects
 if($LASTEXITCODE -ne 0){throw 'Probe link failed'}
 & $Python -I ../unlock/verify_pe.py "$out/BOOTX64.EFI" "$out/PROBE.map" --output "$out/pe-verification.json"
 if($LASTEXITCODE -ne 0){throw 'Probe PE verification failed'}
 [ordered]@{Mode=if($Ad104GopTest){'ad104-msi-text-then-gop-consumer-test'}elseif($Ad104TextTest){'ad104-msi-pcd-capture-then-one-shot-text-test'}elseif($Ad104PcdCapture){'ad104-msi-pcd-producer-capture'}elseif($Ad104OutputObservation){'ad104-msi-output-and-pcd-observation'}elseif($Ad104EdidTest){'ad104-msi-one-shot-edid-lifecycle-test'}elseif($Ad104Preflight){'ad104-msi-runtime-preflight-observation-then-windows-usb'}elseif($Ad104Resources){'ad104-msi-resource-observation-then-windows-usb'}elseif($Ad104FirmwareRom){'ad104-msi-firmware-rom-buffer-then-windows-usb'}elseif($Ad104Metadata){'ad104-msi-metadata-only-then-windows-usb'}elseif($Ad104Msi){'ad104-msi-read-only-probe-then-windows-usb'}else{'generic-read-only-probe-then-windows-usb'};
   CanQueryBarResources=[bool]$Ad104Resources;CanQueryPcdBoolean=[bool]$Ad104OutputObservation;CanCapturePcdProducer=[bool]$Ad104PcdCapture;CanReleaseGopConsumer=[bool]$Ad104GopTest;CanReleasePciOwner=$false;
   CanReadGpuMmio=(!$Ad104Metadata);CanDereferenceRomImage=[bool]$Ad104FirmwareRom;
  WindowsBootIdentity=if($WindowsMbr){'exact-mbr-extent-and-boot-manager-hash'}else{'gpt-partition-guid'};
  CanUnlock=$false;CanDetach=([bool]$Ad104EdidTest -or [bool]$Ad104TextTest);WritesFirmwareVariables=$false;HardwareTested=$false;Defines=$defines
  EfiSha256=(Get-FileHash -LiteralPath "$out/BOOTX64.EFI").Hash.ToLowerInvariant();BuiltUtc=[DateTime]::UtcNow.ToString('o')
   Sources=@(($sources+@('diagnostic.h','media.h','probe.h','firmware-rom.h','ad104-preflight.h','ad104-edid.h','output-observation.h','pcd-producer.h','text-display.h','gop-step.h','platform-config.h')) | ForEach-Object {[ordered]@{Path=$_;Sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}})
 } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$out/manifest.json" -Encoding utf8
 "Built $out/BOOTX64.EFI; CanDetach=$([bool]$Ad104EdidTest -or [bool]$Ad104TextTest); hardware untested."
} finally {Pop-Location}
