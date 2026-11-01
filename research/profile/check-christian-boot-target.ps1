# Read-only boot target discovery for a future build. No mount/BCD/firmware writes.
param([string]$Results='C:\GPU-Unlock\Results')
$ErrorActionPreference='Stop'
$parts=@(Get-Partition | Where-Object IsSystem)
if($parts.Count -ne 1 -or !$parts[0].Guid){throw 'Expected one identifiable Windows system ESP; send this error'}
$p=$parts[0];$disk=Get-Disk -Number $p.DiskNumber
if($disk.PartitionStyle -ne 'GPT' -or $disk.BusType -eq 'USB'){throw 'System partition is not the expected internal GPT device'}
$vol=@($p | Get-Volume)
if($vol.Count -ne 1 -or $vol[0].FileSystem -ne 'FAT32'){throw 'Expected FAT32 system ESP'}
$secure=$null;$secureError=$null
try{$secure=Confirm-SecureBootUEFI}catch{$secureError='Secure Boot status unavailable; no setting changed'}
$hash=$null;$hashError=$null
try{$hash=(Get-FileHash -LiteralPath (Join-Path $vol[0].Path 'EFI/Microsoft/Boot/bootmgfw.efi') -Algorithm SHA256).Hash.ToLowerInvariant()}catch{$hashError='Bootloader read unavailable; no mount or permission changes attempted'}
$out=Join-Path $Results ('christian-boot-target-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($out)
$report=[ordered]@{schema='christian-boot-target-v1';windows_esp_guid=([guid]$p.Guid).ToString();partition_number=$p.PartitionNumber;partition_offset=$p.Offset;partition_bytes=$p.Size;disk_bus_type=[string]$disk.BusType;filesystem=$vol[0].FileSystem;secure_boot_enabled=$secure;secure_boot_error=$secureError;windows_bootloader_sha256=$hash;bootloader_read_error=$hashError;firmware_written=$false;boot_order_written=$false;partition_mounted=$false;gpu_accessed=$false;unlock_proven=$false}
[IO.File]::WriteAllText((Join-Path $out 'boot-target.json'),($report | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$zip=$out+'.zip';Compress-Archive -LiteralPath $out -DestinationPath $zip
[ordered]@{evidence_zip=$zip;next='Attach this ZIP. Do not change Secure Boot, mount partitions or reboot.'} | ConvertTo-Json
