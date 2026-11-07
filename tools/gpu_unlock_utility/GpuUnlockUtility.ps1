<#
.SYNOPSIS
    Windows GPU UNLOCK - Executive Control, Compatibility Checker & Deployment Utility
.DESCRIPTION
    A comprehensive Windows utility for the Windows-GPU-UNLOCK project.
    Provides hardware compatibility auditing, safety pre-flight checks,
    offline compatibility checking and analysis of pre-boot EFI captures,
    report comparisons, USB and internal EFI boot deployment, live GPU telemetry,
    and 1-click emergency recovery.
.PARAMETER Cli
    Runs in command-line mode instead of launching the WPF GUI.
.PARAMETER Action
    CLI action: 'Audit', 'Preflight', 'CheckUsb', 'DeployUsb', 'RestoreWindows',
    'Telemetry', 'CheckCaptures', 'CompareReports'.
.PARAMETER DriveLetter
    Drive letter for USB or ESP operations (e.g., 'E').
.PARAMETER CapturePath
    Path to existing capture folder containing DIAGnn.TXT, IMGnn.BIN, PROM.BIN for analysis.
.PARAMETER LeftReport
    Path to first JSON report for comparison.
.PARAMETER RightReport
    Path to second JSON report for comparison.
.PARAMETER ExportPath
    Optional destination path to save JSON compatibility report.
.PARAMETER Lang
    Language for reports and explanations ('en' or 'ko'). Defaults to 'en'.
.PARAMETER Json
    Switch to output raw JSON in CLI mode.
#>
[CmdletBinding()]
param(
    [switch]$Cli,
    [ValidateSet('Audit', 'Preflight', 'CheckUsb', 'DeployUsb', 'RestoreWindows', 'Telemetry', 'CheckCaptures', 'CompareReports')]
    [string]$Action = 'Audit',
    [string]$DriveLetter,
    [string]$CapturePath,
    [string]$LeftReport,
    [string]$RightReport,
    [string]$ExportPath,
    [ValidateSet('en', 'ko')]
    [string]$Lang = 'en',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Script:AssetsPath = Join-Path $Script:RepoRoot 'assets'
$Script:ReleaseEfi = Join-Path $Script:RepoRoot 'release\EFI\BOOT\BOOTX64.EFI'
$Script:ProvenanceFile = Join-Path $Script:RepoRoot 'release\provenance.json'
$Script:AssetsJson = Join-Path $Script:RepoRoot 'unlock\assets.json'
$Script:ProvenJson = Join-Path $Script:RepoRoot 'research\profile\proven.json'
$Script:CheckerPy = Join-Path $Script:RepoRoot 'research\profile\check-compatibility.py'
$Script:ComparatorPy = Join-Path $Script:RepoRoot 'research\profile\compare-compatibility.py'

# --- CORE ENGINE FUNCTIONS ---

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Sha256Hash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GpuHardwareInfo {
    $info = [ordered]@{}
    try {
        $board = Get-CimInstance Win32_BaseBoard -Property Manufacturer, Product | Select-Object -First 1
        $cpu = Get-CimInstance Win32_Processor -Property Name, Manufacturer | Select-Object -First 1
        $bios = Get-CimInstance Win32_BIOS -Property Manufacturer, SMBIOSBIOSVersion | Select-Object -First 1
        $os = Get-CimInstance Win32_OperatingSystem -Property Caption, Version, BuildNumber, OSArchitecture | Select-Object -First 1
        $videoControllers = @(Get-CimInstance Win32_VideoController -Property Name, PNPDeviceID, DriverVersion, AdapterRAM)

        $info['Motherboard'] = "$($board.Manufacturer) $($board.Product)".Trim()
        $info['BoardProduct'] = [string]$board.Product
        $info['BIOS'] = "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)".Trim()
        $info['BIOSVersion'] = [string]$bios.SMBIOSBIOSVersion
        $info['CPU'] = [string]$cpu.Name
        $info['OS'] = "$($os.Caption) ($($os.Version) Build $($os.BuildNumber))"

        $gpus = @()
        foreach ($vc in $videoControllers) {
            $pnp = [string]$vc.PNPDeviceID
            $devMatch = [regex]::Match($pnp, 'VEN_([0-9A-Fa-f]{4})&DEV_([0-9A-Fa-f]{4})(?:&SUBSYS_([0-9A-Fa-f]{8}))?', 'IgnoreCase')
            $pci = $null
            if ($devMatch.Success) {
                $ven = $devMatch.Groups[1].Value.ToLowerInvariant()
                $dev = $devMatch.Groups[2].Value.ToLowerInvariant()
                $subsys = $devMatch.Groups[3].Value.ToLowerInvariant()
                $subVen = if ($subsys.Length -ge 8) { $subsys.Substring(4, 4) } else { "" }
                $subDev = if ($subsys.Length -ge 8) { $subsys.Substring(0, 4) } else { "" }
                $pci = @{
                    Vendor = $ven
                    Device = $dev
                    Subsystem = $subsys
                    SubsystemVendor = $subVen
                    SubsystemDevice = $subDev
                }
            }

            # Identify architecture and known models
            $arch = "Unknown"
            $family = "Unknown"
            $isAmpere = $false
            if ($pci -and $pci.Vendor -eq '10de') {
                switch ($pci.Device) {
                    '2204' { $arch = "RTX 3090 (GA102)"; $family = "GA102"; $isAmpere = $true }
                    '2203' { $arch = "RTX 3090 Ti (GA102)"; $family = "GA102"; $isAmpere = $true }
                    '2206' { $arch = "RTX 3080 (GA102)"; $family = "GA102"; $isAmpere = $true }
                    '220a' { $arch = "RTX 3080 12GB (GA102)"; $family = "GA102"; $isAmpere = $true }
                    '2208' { $arch = "RTX 3080 Ti (GA102)"; $family = "GA102"; $isAmpere = $true }
                    '2484' { $arch = "RTX 3070 (GA104)"; $family = "GA104"; $isAmpere = $true }
                    '2482' { $arch = "RTX 3070 Ti (GA104)"; $family = "GA104"; $isAmpere = $true }
                    '2487' { $arch = "RTX 3060 12GB (GA104)"; $family = "GA104"; $isAmpere = $true }
                    '24c9' { $arch = "RTX 3060 Ti (GA104)"; $family = "GA104"; $isAmpere = $true }
                    '2503' { $arch = "RTX 3060 (GA106)"; $family = "GA106"; $isAmpere = $true }
                    '2504' { $arch = "RTX 3060 12GB (GA106)"; $family = "GA106"; $isAmpere = $true }
                    default {
                        if ($vc.Name -match 'RTX 30') { $arch = "Ampere Family"; $family = "GA10x"; $isAmpere = $true }
                    }
                }
            }

            $vramMb = [math]::Round([double]$vc.AdapterRAM / 1MB)
            $gpus += [ordered]@{
                Name = [string]$vc.Name
                DriverVersion = [string]$vc.DriverVersion
                PCI = $pci
                Architecture = $arch
                Family = $family
                IsAmpere = $isAmpere
                VramMb = $vramMb
            }
        }
        $info['GPUs'] = $gpus

        # Check matching profile
        $match = "No exact fixed profile match. Candidate for Local Profile / USB route."
        $nvidiaGpu = $gpus | Where-Object { $_.IsAmpere } | Select-Object -First 1
        if ($nvidiaGpu) {
            $bp = $info['BoardProduct']
            $bv = $info['BIOSVersion']
            if ($bp -match 'B650M-PLUS' -and $bv -eq '3057' -and $nvidiaGpu.PCI.Device -eq '2204') {
                $match = "Exact Match: b650m-3090fe (ASUS TUF B650M-PLUS WIFI / 3057 / RTX 3090 FE)"
            } elseif ($bp -match 'B660M-E' -and $bv -eq '4003' -and $nvidiaGpu.PCI.Device -eq '2482') {
                $match = "Exact Match: b660m-3070ti (ASUS TUF B660M-E D4 / 4003 / RTX 3070 Ti)"
            } elseif ($bp -match 'X870' -and $bv -eq 'F13d' -and $nvidiaGpu.PCI.Device -eq '2203') {
                $match = "Exact Match: x870-3090ti (Gigabyte X870 AORUS ELITE / F13d / RTX 3090 Ti)"
            } elseif ($bp -match 'B660-PLUS' -and $bv -eq '3010' -and $nvidiaGpu.PCI.Device -in @('2487','2504')) {
                $match = "Exact Match: b660plus-3060 (ASUS PRIME B660-PLUS D4 / 3010 / RTX 3060)"
            } elseif ($bp -match 'H610M H' -and $bv -eq 'FC' -and $nvidiaGpu.PCI.Device -eq '2504') {
                $match = "Exact Match: h610m-3060 (Gigabyte H610M H / FC / RTX 3060 GA106)"
            } elseif ($nvidiaGpu.IsAmpere) {
                $match = "Eligible GPU ($($nvidiaGpu.Architecture)): Compatible with Headless USB / Local Profile route."
            }
        }
        $info['ProfileAssessment'] = $match

    } catch {
        $info['Error'] = $_.Exception.Message
    }
    return $info
}

function Get-PreflightChecks {
    $checks = [ordered]@{}

    # 1. Administrator rights
    $isAdmin = Test-IsAdmin
    $checks['IsAdmin'] = @{
        Status = if ($isAdmin) { 'PASS' } else { 'WARN' }
        Title = "Administrative Privileges"
        Detail = if ($isAdmin) { "Running as Administrator. Full deployment and BCD controls enabled." }
                 else { "Running in Standard User mode. Read-only audits active; elevation required for BCD/ESP writes." }
    }

    # 2. Secure Boot status
    $sbEnabled = $null
    try {
        $sbReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue
        if ($sbReg) {
            $sbEnabled = ($sbReg.UEFISecureBootEnabled -eq 1)
        }
    } catch {}

    if ($sbEnabled -eq $null -and $isAdmin) {
        try { $sbEnabled = Confirm-SecureBootUEFI } catch {}
    }

    $checks['SecureBoot'] = @{
        Status = if ($sbEnabled -eq $false) { 'PASS' } elseif ($sbEnabled -eq $true) { 'FAIL' } else { 'UNKNOWN' }
        Title = "UEFI Secure Boot"
        Detail = if ($sbEnabled -eq $false) { "Disabled. Unsigned experimental EFI payloads can boot freely." }
                 elseif ($sbEnabled -eq $true) { "ENABLED. You MUST disable Secure Boot in BIOS/UEFI settings before booting unlock EFI." }
                 else { "Could not query Secure Boot state automatically. Ensure it is disabled in BIOS." }
    }

    # 3. Windows Fast Startup
    $hiber = $null
    try {
        $powerReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -ErrorAction SilentlyContinue
        if ($powerReg) {
            $hiber = ($powerReg.HiberbootEnabled -eq 1)
        }
    } catch {}

    $checks['FastStartup'] = @{
        Status = if ($hiber -eq $false) { 'PASS' } elseif ($hiber -eq $true) { 'WARN' } else { 'UNKNOWN' }
        Title = "Windows Fast Startup"
        Detail = if ($hiber -eq $false) { "Disabled. Cold boot initializes hardware cleanly." }
                 elseif ($hiber -eq $true) { "ENABLED (Hybrid Sleep). Must be disabled so PCIe hardware resets cleanly on cold boot." }
                 else { "Status not detected." }
    }

    # 4. BitLocker Protection
    $bitLockerStatus = "NOT_PROTECTED"
    $bitLockerDetail = "No active BitLocker protection detected on C:."
    if ($isAdmin) {
        try {
            $bl = Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue
            if ($bl) {
                if ($bl.ProtectionStatus -eq 1 -or $bl.VolumeStatus -ne 0) {
                    $bitLockerStatus = "WARN"
                    $bitLockerDetail = "BitLocker protection is ON ($($bl.ProtectionStatus)). Suspend BitLocker before testing UEFI bootloader to prevent recovery prompt."
                } else {
                    $bitLockerStatus = "PASS"
                    $bitLockerDetail = "C: is fully decrypted / BitLocker protection is OFF."
                }
            }
        } catch {
            $bitLockerStatus = "UNKNOWN"
            $bitLockerDetail = "BitLocker status check error: $($_.Exception.Message)"
        }
    } else {
        $bitLockerStatus = "NOTICE"
        $bitLockerDetail = "Elevation required to inspect BitLocker. Verify in Windows Security that BitLocker is suspended if active."
    }

    $checks['BitLocker'] = @{
        Status = $bitLockerStatus
        Title = "BitLocker C: Encryption"
        Detail = $bitLockerDetail
    }

    # 5. Release EFI Binary
    $efiValid = $false
    $efiDetail = "Release EFI binary missing."
    if (Test-Path -LiteralPath $Script:ReleaseEfi) {
        $efiHash = Get-Sha256Hash $Script:ReleaseEfi
        $prov = if (Test-Path -LiteralPath $Script:ProvenanceFile) { Get-Content -LiteralPath $Script:ProvenanceFile -Raw | ConvertFrom-Json } else { $null }
        if ($prov -and $efiHash -eq $prov.efi_sha256.ToLowerInvariant()) {
            $efiValid = $true
            $efiDetail = "Valid (SHA256: $($efiHash.Substring(0,16))..., matches provenance)."
        } else {
            $efiDetail = "EFI binary present but checksum does not match provenance.json."
        }
    }
    $checks['ReleaseEFI'] = @{
        Status = if ($efiValid) { 'PASS' } else { 'WARN' }
        Title = "Pre-Compiled Release BOOTX64.EFI"
        Detail = $efiDetail
    }

    # 6. Firmware Assets Check
    $assetsValid = $false
    $assetMissing = @()
    if (Test-Path -LiteralPath $Script:AssetsJson) {
        $specs = Get-Content -LiteralPath $Script:AssetsJson -Raw | ConvertFrom-Json
        $assetOkCount = 0
        foreach ($spec in $specs) {
            $f = Join-Path $Script:AssetsPath $spec.Name
            if (Test-Path -LiteralPath $f) {
                $h = Get-Sha256Hash $f
                if ($h -eq $spec.Sha256.ToLowerInvariant()) {
                    $assetOkCount++
                } else {
                    $assetMissing += "$($spec.Name) (Checksum mismatch)"
                }
            } else {
                $assetMissing += "$($spec.Name) (Missing)"
            }
        }
        if ($assetOkCount -eq $specs.Count) {
            $assetsValid = $true
            $assetDetail = "All 5 required GA102 firmware assets verified in assets/."
        } else {
            $assetDetail = "$($assetOkCount)/$($specs.Count) assets present. Missing/Invalid: $($assetMissing -join ', ')"
        }
    } else {
        $assetDetail = "assets.json missing from repository."
    }

    $checks['FirmwareAssets'] = @{
        Status = if ($assetsValid) { 'PASS' } else { 'WARN' }
        Title = "Firmware Asset Files (GA102)"
        Detail = $assetDetail
    }

    return $checks
}

function Disable-WindowsFastStartup {
    if (-not (Test-IsAdmin)) {
        throw "Administrator privileges required to change Fast Startup setting."
    }
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $path -Name HiberbootEnabled -Value 0 -Type DWord -Force
    return "Fast Startup has been disabled (HiberbootEnabled = 0)."
}

function Get-RemovableDrives {
    $drives = @()
    try {
        $disks = @(Get-Disk | Where-Object { $_.BusType -eq 'USB' -or $_.MediaType -eq 'Removable' })
        foreach ($disk in $disks) {
            $parts = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue)
            foreach ($part in $parts) {
                if ($part.DriveLetter) {
                    $vol = Get-Volume -DriveLetter $part.DriveLetter -ErrorAction SilentlyContinue
                    $drives += [pscustomobject]@{
                        DriveLetter = "$($part.DriveLetter):"
                        Letter = [string]$part.DriveLetter
                        DiskNumber = $disk.Number
                        FriendlyName = "$($disk.FriendlyName) ($($part.DriveLetter):)"
                        FileSystem = [string]$vol.FileSystem
                        SizeGb = [math]::Round($part.Size / 1GB, 2)
                        IsBoot = [bool]$disk.IsBoot
                        IsSystem = [bool]$part.IsSystem
                    }
                }
            }
        }
    } catch {}
    return $drives
}

function Find-UsbCaptureFolders {
    $found = @()
    $drives = Get-RemovableDrives
    foreach ($d in $drives) {
        $root = "$($d.Letter):\"
        # Check root
        $diagRoot = @(Get-ChildItem -LiteralPath $root -Filter "DIAG*.TXT" -File -ErrorAction SilentlyContinue)
        if ($diagRoot.Count -gt 0) {
            $found += $root.TrimEnd('\')
        }
        # Check RTX3090-UNLOCK
        $rtxDir = Join-Path $root "RTX3090-UNLOCK"
        if (Test-Path -LiteralPath $rtxDir) {
            $found += $rtxDir
        }
    }
    return @($found | Select-Object -Unique)
}

function Deploy-ToUsb([string]$Letter) {
    $cleanLetter = $Letter.TrimEnd(':')
    $driveRoot = "$($cleanLetter):\"
    if (-not (Test-Path -LiteralPath $driveRoot)) {
        throw "Target drive '$driveRoot' does not exist."
    }

    $vol = Get-Volume -DriveLetter $cleanLetter
    if ($vol.FileSystem -ne 'FAT32') {
        throw "Drive $($cleanLetter): is formatted as $($vol.FileSystem). UEFI requires FAT32."
    }

    $targetBootDir = Join-Path $driveRoot "EFI\BOOT"
    $targetPayloadDir = Join-Path $driveRoot "RTX3090-UNLOCK"
    $targetAssetsDir = Join-Path $targetPayloadDir "ASSETS"

    New-Item -ItemType Directory -Path $targetBootDir -Force | Out-Null
    New-Item -ItemType Directory -Path $targetAssetsDir -Force | Out-Null

    # Copy Release BOOTX64.EFI
    if (-not (Test-Path -LiteralPath $Script:ReleaseEfi)) {
        throw "Release BOOTX64.EFI not found in release/EFI/BOOT/BOOTX64.EFI"
    }
    Copy-Item -LiteralPath $Script:ReleaseEfi -Destination (Join-Path $targetBootDir "BOOTX64.EFI") -Force

    # Copy Assets if present
    $assetsCopied = 0
    if (Test-Path -LiteralPath $Script:AssetsPath) {
        $assets = Get-ChildItem -LiteralPath $Script:AssetsPath -Filter "*.bin" -File
        foreach ($a in $assets) {
            Copy-Item -LiteralPath $a.FullName -Destination (Join-Path $targetAssetsDir $a.Name) -Force
            $assetsCopied++
        }
    }

    # Copy README & Documentation
    $readmeContent = @"
# Windows GPU UNLOCK - Bootable USB

## Instructions:
1. Ensure Secure Boot is DISABLED in your motherboard BIOS.
2. Shut down your PC completely (Power Off). Do not use Restart.
3. Power on and press your motherboard Boot Menu hotkey:
   - ASUS: F8
   - Gigabyte: F12
   - MSI: F11
   - ASRock: F11
4. Select this USB drive from the Boot Menu (e.g., 'UEFI: USB Drive').
5. The unlock EFI application will execute, unlock the GPU registers (SS0/SS1),
   perform PCIe Function Level Reset, and immediately handoff/chain-load Windows Boot Manager.
6. The display may flicker or turn black momentarily during GOP removal and restore.
7. Once Windows loads, open the GPU Unlock Utility to verify active unlock and run GEMM compute benchmark!

Safety Notice: If display does not return after 30 seconds, power off the PC and boot normally into Windows.
"@
    Set-Content -LiteralPath (Join-Path $driveRoot "USB-README.md") -Value $readmeContent -Encoding utf8

    return [pscustomobject]@{
        Drive = $driveRoot
        BootEfi = (Join-Path $targetBootDir "BOOTX64.EFI")
        AssetsCopied = $assetsCopied
        Status = "Successfully staged USB Unlock files."
    }
}

function Restore-WindowsFirstBootOrder {
    if (-not (Test-IsAdmin)) {
        throw "Administrator privileges required to modify UEFI BCD boot order."
    }
    $headlessScript = Join-Path $Script:RepoRoot "internal-boot\Headless.ps1"
    if (Test-Path -LiteralPath $headlessScript) {
        $res = & powershell -NoProfile -ExecutionPolicy Bypass -File $headlessScript -RestoreWindowsFirst
        return ($res -join "`r`n")
    } else {
        $fwText = & bcdedit /enum '{fwbootmgr}'
        $m = [regex]::Match($fwText, '(?ms)^displayorder\s+(.*?)(?=\r?\n\S|\z)')
        if ($m.Success) {
            $ids = @([regex]::Matches($m.Groups[1].Value, '\{(?:bootmgr|[0-9a-f-]{36})\}') | ForEach-Object { $_.Value })
            $newOrder = @('{bootmgr}') + @($ids | Where-Object { $_ -ne '{bootmgr}' })
            $argsOrder = @('/set', '{fwbootmgr}', 'displayorder') + $newOrder
            & bcdedit @argsOrder
            return "Restored {bootmgr} as primary boot option."
        }
        return "Could not query {fwbootmgr}."
    }
}

function Get-GpuTelemetryLive {
    $telemetry = [ordered]@{}
    try {
        $smiOut = & nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit,clocks.sm,clocks.mem --format=csv,noheader,nounits 2>&1
        $line = (@($smiOut) -join "`n").Trim()
        if ($line) {
            $parts = $line.Split(',') | ForEach-Object { $_.Trim() }
            if ($parts.Count -ge 10) {
                $telemetry['Name'] = $parts[0]
                $telemetry['Driver'] = $parts[1]
                $telemetry['TempC'] = $parts[2]
                $telemetry['UtilGpu'] = "$($parts[3]) %"
                $telemetry['MemUsedMb'] = "$($parts[4]) MB"
                $telemetry['MemTotalMb'] = "$($parts[5]) MB"
                $telemetry['PowerDrawW'] = "$($parts[6]) W"
                $telemetry['PowerLimitW'] = "$($parts[7]) W"
                $telemetry['ClockSmMhz'] = "$($parts[8]) MHz"
                $telemetry['ClockMemMhz'] = "$($parts[9]) MHz"
            }
        } else {
            $telemetry['Error'] = "nvidia-smi not available or GPU query failed."
        }
    } catch {
        $telemetry['Error'] = $_.Exception.Message
    }
    return $telemetry
}

# --- OFFLINE COMPATIBILITY CHECKER & ANALYSER ENGINE ---

function Invoke-OfflineCompatibilityCheck {
    param(
        [Parameter(Mandatory)][string]$Folder,
        [string]$Language = 'en'
    )

    if (-not (Test-Path -LiteralPath $Folder)) {
        throw "Capture directory '$Folder' not found."
    }
    if (-not (Test-Path -LiteralPath $Script:CheckerPy)) {
        throw "Offline compatibility checker script not found at $Script:CheckerPy"
    }

    $raw = & python -I $Script:CheckerPy $Folder --lang $Language --json 2>&1
    $rawText = ($raw -join "`n").Trim()

    $jsonObj = $null
    try {
        $jsonObj = $rawText | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{
            Status = 'error'
            Badge = '[ERROR]'
            BadgeColor = 'Tomato'
            Summary = "Failed to parse checker output into JSON."
            Scope = "Unknown"
            Limitations = "Python engine error or malformed diagnostic data."
            NextStep = "Ensure Python 3.10+ is installed and verify capture file permissions."
            CaptureCount = 0
            Checks = @()
            Observations = @()
            RawJson = ""
            RawText = $rawText
            Parsed = $null
        }
    }

    $badge = switch ($jsonObj.status) {
        'candidate'     { '[CANDIDATE] Eligible for Local Profile' }
        'needs_data'    { '[NEEDS DATA] More Captures / Files Required' }
        'outside_scope' { '[OUTSIDE SCOPE] Hardware / Layout Outside Envelope' }
        'invalid_data'  { '[INVALID DATA] Inconsistent / Corrupted Observations' }
        default         { "[$($jsonObj.status.ToUpper())]" }
    }

    $badgeColor = switch ($jsonObj.status) {
        'candidate'     { 'LightGreen' }
        'needs_data'    { 'Gold' }
        'outside_scope' { 'DarkOrange' }
        'invalid_data'  { 'Tomato' }
        default         { 'Gray' }
    }

    return [pscustomobject]@{
        Status = [string]$jsonObj.status
        Badge = $badge
        BadgeColor = $badgeColor
        Summary = [string]$jsonObj.summary
        Scope = [string]$jsonObj.scope
        Limitations = [string]$jsonObj.limitations
        NextStep = [string]$jsonObj.next_step
        CaptureCount = [int]$jsonObj.capture_count
        Checks = @($jsonObj.checks)
        Observations = @($jsonObj.observations)
        RawJson = $rawText
        RawText = $rawText
        Parsed = $jsonObj
    }
}

function Invoke-CompareCompatibilityReports {
    param(
        [Parameter(Mandatory)][string]$LeftReportPath,
        [Parameter(Mandatory)][string]$RightReportPath,
        [string]$Language = 'en'
    )

    if (-not (Test-Path -LiteralPath $LeftReportPath)) { throw "Reference report '$LeftReportPath' does not exist." }
    if (-not (Test-Path -LiteralPath $RightReportPath)) { throw "Target report '$RightReportPath' does not exist." }
    if (-not (Test-Path -LiteralPath $Script:ComparatorPy)) { throw "compare-compatibility.py not found at $Script:ComparatorPy" }

    $res = & python -I $Script:ComparatorPy $LeftReportPath $RightReportPath --lang $Language 2>&1
    return ($res -join "`r`n")
}

# --- CLI DISPATCHER ---

if ($Cli) {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " Windows GPU UNLOCK - CLI Management Utility" -ForegroundColor White
    Write-Host " Repository: $Script:RepoRoot" -ForegroundColor DarkGray
    Write-Host "==========================================================" -ForegroundColor Cyan

    switch ($Action) {
        'Audit' {
            Write-Host "`n[+] Executing System and GPU Compatibility Audit..." -ForegroundColor Yellow
            $audit = Get-GpuHardwareInfo
            $audit | ConvertTo-Json -Depth 5 | Write-Output
        }
        'Preflight' {
            Write-Host "`n[+] Running Safety Pre-Flight Checks..." -ForegroundColor Yellow
            $checks = Get-PreflightChecks
            foreach ($k in $checks.Keys) {
                $c = $checks[$k]
                $color = switch ($c.Status) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'Cyan' } }
                Write-Host "[$($c.Status)] $($c.Title): " -ForegroundColor $color -NoNewline
                Write-Host $c.Detail
            }
        }
        'CheckUsb' {
            Write-Host "`n[+] Querying Connected USB Storage Devices..." -ForegroundColor Yellow
            $usb = Get-RemovableDrives
            if ($usb.Count -eq 0) {
                Write-Host "No removable USB drives detected." -ForegroundColor DarkYellow
            } else {
                $usb | Format-Table DriveLetter, FriendlyName, FileSystem, SizeGb, IsBoot
            }
        }
        'DeployUsb' {
            if (-not $DriveLetter) { throw "Please specify -DriveLetter (e.g. -DriveLetter E)" }
            Write-Host "`n[+] Deploying USB Unlock to $DriveLetter..." -ForegroundColor Yellow
            $res = Deploy-ToUsb $DriveLetter
            $res | Format-List
        }
        'RestoreWindows' {
            Write-Host "`n[+] Restoring Standard Windows Boot Order..." -ForegroundColor Yellow
            $res = Restore-WindowsFirstBootOrder
            Write-Host $res -ForegroundColor Green
        }
        'Telemetry' {
            Write-Host "`n[+] Live GPU Telemetry:" -ForegroundColor Yellow
            $telem = Get-GpuTelemetryLive
            [pscustomobject]$telem | Format-List
        }
        'CheckCaptures' {
            if (-not $CapturePath) { throw "Please specify -CapturePath" }
            Write-Host "`n[+] Running Offline Compatibility Checker on: $CapturePath (Lang: $Lang)..." -ForegroundColor Yellow
            $res = Invoke-OfflineCompatibilityCheck -Folder $CapturePath -Language $Lang

            if ($Json) {
                Write-Output $res.RawJson
            } else {
                Write-Host "`nAssessment: $($res.Badge)" -ForegroundColor $(switch ($res.Status) { 'candidate' { 'Green' } 'needs_data' { 'Yellow' } default { 'Red' } })
                Write-Host "Summary:    $($res.Summary)" -ForegroundColor White
                Write-Host "Captures:   $($res.CaptureCount) found" -ForegroundColor Cyan
                Write-Host "Scope:      $($res.Scope)" -ForegroundColor DarkGray
                Write-Host "`nChecks Evaluated:" -ForegroundColor Yellow
                foreach ($chk in $res.Checks) {
                    $stateColor = switch ($chk.state) { 'candidate' { 'Green' } 'needs_data' { 'Yellow' } default { 'Red' } }
                    Write-Host "  [$($chk.state.ToUpper())] $($chk.code): $($chk.message)" -ForegroundColor $stateColor
                }
                Write-Host "`nNext Step Guidance:" -ForegroundColor Yellow
                Write-Host "$($res.NextStep)`n" -ForegroundColor Cyan
            }

            if ($ExportPath) {
                Set-Content -LiteralPath $ExportPath -Value $res.RawJson -Encoding utf8
                Write-Host "[+] Report exported to $ExportPath" -ForegroundColor Green
            }
        }
        'CompareReports' {
            if (-not $LeftReport -or -not $RightReport) { throw "Please specify -LeftReport and -RightReport" }
            Write-Host "`n[+] Comparing Compatibility Reports: '$LeftReport' vs '$RightReport'..." -ForegroundColor Yellow
            $diff = Invoke-CompareCompatibilityReports -LeftReportPath $LeftReport -RightReportPath $RightReport -Language $Lang
            Write-Output $diff
        }
    }
    exit 0
}

# --- WPF GUI IMPLEMENTATION ---

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows GPU UNLOCK - Control, Compatibility &amp; Deployment Utility"
        Height="820" Width="1080"
        WindowStartupLocation="CenterScreen"
        Background="#181825"
        Foreground="#CDD6F4"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#1E1E2E"/>
            <Setter Property="Foreground" Value="#A6ADC8"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="{TemplateBinding Background}" BorderThickness="0,0,0,3" BorderBrush="Transparent" Padding="{TemplateBinding Padding}">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#252538"/>
                                <Setter TargetName="Border" Property="BorderBrush" Value="#89B4FA"/>
                                <Setter Property="Foreground" Value="#89B4FA"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="#CDD6F4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="BtnBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="BtnBorder" Property="Background" Value="#45475A"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="BtnBorder" Property="Background" Value="#585B70"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- TOP BAR / HEADER -->
        <Border Grid.Row="0" Background="#1E1E2E" CornerRadius="8" Padding="16,14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="Windows GPU UNLOCK" FontSize="20" FontWeight="Bold" Foreground="#89B4FA"/>
                    <TextBlock Text="Offline compatibility checker, safety pre-flight validator, and EFI deployment manager" FontSize="12" Foreground="#A6ADC8" Margin="0,3,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Name="BadgeAdmin" Background="#A6E3A1" CornerRadius="4" Padding="10,5" Margin="0,0,10,0">
                        <TextBlock Name="TxtBadgeAdmin" Text="ADMINISTRATOR" FontWeight="Bold" FontSize="11" Foreground="#11111B"/>
                    </Border>
                    <Button Name="BtnElevate" Content="Elevate to Admin" Background="#F38BA8" Foreground="#11111B" FontWeight="Bold" Padding="10,5" Visibility="Collapsed"/>
                    <Button Name="BtnRefresh" Content="Refresh All" Margin="10,0,0,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- MAIN TABS -->
        <TabControl Name="MainTabControl" Grid.Row="1" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1">
            <!-- TAB 1: SYSTEM & GPU AUDIT -->
            <TabItem Header="System &amp; GPU Audit">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="Hardware Profile Identification" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,10"/>
                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Name="TxtAssessment" Text="Scanning hardware..." FontSize="13" FontWeight="SemiBold" Foreground="#A6E3A1" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>

                        <Grid Margin="0,0,0,14">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Motherboard & Platform Box -->
                            <Border Grid.Column="0" Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,8,0" BorderBrush="#313244" BorderThickness="1">
                                <StackPanel>
                                    <TextBlock Text="Host Platform Details" FontSize="13" FontWeight="Bold" Foreground="#F9E2AF" Margin="0,0,0,8"/>
                                    <TextBlock Name="TxtBoard" Text="Motherboard: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtBios" Text="BIOS Version: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtCpu" Text="Processor: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtOs" Text="Operating System: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                </StackPanel>
                            </Border>

                            <!-- GPU Details Box -->
                            <Border Grid.Column="1" Background="#252538" CornerRadius="6" Padding="14" Margin="8,0,0,0" BorderBrush="#313244" BorderThickness="1">
                                <StackPanel>
                                    <TextBlock Text="GPU Controller &amp; PCI Details" FontSize="13" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,8"/>
                                    <TextBlock Name="TxtGpuName" Text="GPU: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtGpuPci" Text="PCI VEN/DEV: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtGpuArch" Text="Architecture: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtGpuVram" Text="VRAM: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtGpuDriver" Text="Driver Version: Detecting..." Margin="0,3" Foreground="#CDD6F4"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <TextBlock Text="Supported GPU Families: RTX 3060 (GA104/GA106), RTX 3070, RTX 3070 Ti, RTX 3080, RTX 3090, RTX 3090 Ti. The unlock modifies pre-driver Falcon/GSP selector registers (SS0/SS1) via UEFI pre-boot." FontSize="11" Foreground="#6C7086" TextWrapping="Wrap"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 2: PRE-FLIGHT SAFETY -->
            <TabItem Header="Pre-Flight Safety">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="System Safety &amp; Prerequisite Verification" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,10"/>
                        <TextBlock Text="Prior to attempting any UEFI unlock boot, the host environment must meet critical safety standards to avoid boot lockouts or BitLocker recovery prompts." FontSize="12" Foreground="#A6ADC8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                        <!-- Item: Secure Boot -->
                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Name="IconSecureBoot" Grid.Column="0" Text="[OK]" FontSize="16" FontWeight="Bold" Foreground="#A6E3A1" VerticalAlignment="Center" Margin="0,0,14,0"/>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock Text="UEFI Secure Boot" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtDetailSecureBoot" Text="Checking..." FontSize="12" Foreground="#A6ADC8" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <!-- Item: Fast Startup -->
                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Name="IconFastStartup" Grid.Column="0" Text="[OK]" FontSize="16" FontWeight="Bold" Foreground="#A6E3A1" VerticalAlignment="Center" Margin="0,0,14,0"/>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock Text="Windows Fast Startup" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtDetailFastStartup" Text="Checking..." FontSize="12" Foreground="#A6ADC8" TextWrapping="Wrap"/>
                                </StackPanel>
                                <Button Name="BtnDisableFastStartup" Grid.Column="2" Content="Disable Fast Startup" Background="#F9E2AF" Foreground="#11111B" VerticalAlignment="Center" Visibility="Collapsed"/>
                            </Grid>
                        </Border>

                        <!-- Item: BitLocker -->
                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Name="IconBitLocker" Grid.Column="0" Text="[OK]" FontSize="16" FontWeight="Bold" Foreground="#A6E3A1" VerticalAlignment="Center" Margin="0,0,14,0"/>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock Text="BitLocker C: Encryption" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtDetailBitLocker" Text="Checking..." FontSize="12" Foreground="#A6ADC8" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <!-- Item: Release Binary & Assets -->
                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Name="IconAssets" Grid.Column="0" Text="[OK]" FontSize="16" FontWeight="Bold" Foreground="#A6E3A1" VerticalAlignment="Center" Margin="0,0,14,0"/>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock Text="Release EFI Binary &amp; Firmware Assets" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                                    <TextBlock Name="TxtDetailAssets" Text="Checking..." FontSize="12" Foreground="#A6ADC8" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Grid>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 3: USB UNLOCK DEPLOYER -->
            <TabItem Header="USB Unlock Deployer">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="Headless USB Route (Recommended)" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,10"/>
                        <TextBlock Text="Stages the compiled UEFI unlock bootloader (BOOTX64.EFI) and required payloads onto a FAT32 USB drive. The USB boot performs the unlock and immediately handsoff directly to Windows Boot Manager without resetting the GPU." FontSize="12" Foreground="#A6ADC8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Select Target USB Drive:" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4" Margin="0,0,0,8"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <ComboBox Name="ComboUsbDrives" Grid.Column="0" Height="32" Background="#313244" Foreground="#CDD6F4" VerticalContentAlignment="Center" Padding="8,4"/>
                                    <Button Name="BtnRefreshUsb" Grid.Column="1" Content="Refresh Disks" Margin="10,0,0,0"/>
                                </Grid>
                                <TextBlock Text="* Drive must be formatted as FAT32. Existing files will be preserved." FontSize="11" Foreground="#6C7086" Margin="0,6,0,0"/>
                            </StackPanel>
                        </Border>

                        <Button Name="BtnDeployUsb" Content="Stage Unlock Files to Selected USB" Background="#89B4FA" Foreground="#11111B" FontWeight="Bold" FontSize="13" Padding="16,10" HorizontalAlignment="Left" Margin="0,0,0,14"/>

                        <Border Background="#252538" CornerRadius="6" Padding="14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Motherboard One-Time Boot Menu Guide:" FontWeight="Bold" FontSize="13" Foreground="#F9E2AF" Margin="0,0,0,8"/>
                                <TextBlock Text="1. Power off the system completely (Do not use restart)." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="2. Turn on the PC and immediately press your BIOS Boot Menu hotkey repeatedly:" Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="   - ASUS: F8" FontWeight="SemiBold" Foreground="#89B4FA" Margin="10,1"/>
                                <TextBlock Text="   - Gigabyte / AORUS: F12" FontWeight="SemiBold" Foreground="#89B4FA" Margin="10,1"/>
                                <TextBlock Text="   - MSI: F11" FontWeight="SemiBold" Foreground="#89B4FA" Margin="10,1"/>
                                <TextBlock Text="   - ASRock: F11" FontWeight="SemiBold" Foreground="#89B4FA" Margin="10,1"/>
                                <TextBlock Text="3. Select 'UEFI: [Your USB Name]' from the boot device list." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="4. The unlock will execute, and directly launch Windows Boot Manager." Foreground="#CDD6F4" Margin="0,2"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 4: INTERNAL ESP & BCD -->
            <TabItem Header="Internal ESP Setup">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="Internal Headless ESP Route" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,10"/>
                        <TextBlock Text="Configures an internal dedicated FAT32 ESP partition and registers a UEFI BCD boot entry ('GPU Headless UNLOCK - EXPERIMENTAL'). Allows direct F8 testing from internal SSD." FontSize="12" Foreground="#A6ADC8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Dedicated ESP Partition Prerequisites:" FontWeight="Bold" FontSize="13" Foreground="#F9E2AF" Margin="0,0,0,8"/>
                                <TextBlock Text="* Must be a separate GPT FAT32 partition of at least 1 GiB." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="* Must NEVER be the primary Windows EFI partition." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="* Must be assigned a temporary drive letter (e.g. U:)." Foreground="#CDD6F4" Margin="0,2"/>
                            </StackPanel>
                        </Border>

                        <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                            <Button Name="BtnRunInternalConfigure" Content="Configure Internal Boot Config" Margin="0,0,10,0"/>
                            <Button Name="BtnRestoreWindowsBcd" Content="Restore Windows Boot Priority" Background="#F38BA8" Foreground="#11111B"/>
                        </StackPanel>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 5: OFFLINE COMPATIBILITY CHECKER & ANALYSER -->
            <TabItem Header="🔍 Offline Compatibility Checker">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="Offline Compatibility Checker &amp; Analyser" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,8"/>
                        <TextBlock Text="Analyzes pre-boot EFI hardware captures (DIAGnn.TXT, IMGnn.BIN, PROM.BIN) against the project's proven hardware envelope. Operates 100% read-only: does not execute firmware, touch hardware, or modify boot settings." FontSize="12" Foreground="#A6ADC8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                        <!-- Capture Folder Picker Box -->
                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Select Capture Folder (with DIAGnn.TXT, IMGnn.BIN, PROM.BIN):" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4" Margin="0,0,0,8"/>
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox Name="TxtCaptureFolder" Grid.Column="0" Height="32" Background="#181825" Foreground="#CDD6F4" BorderBrush="#45475A" VerticalContentAlignment="Center" Padding="8,4" Text="D:\RTX3090-UNLOCK"/>
                                    <Button Name="BtnBrowseCaptureFolder" Grid.Column="1" Content="📁 Browse..." Margin="8,0,0,0" Padding="12,6"/>
                                    <Button Name="BtnDetectUsbCaptures" Grid.Column="2" Content="🔍 Auto-Detect on USB" Margin="8,0,0,0" Padding="12,6"/>
                                </Grid>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Language:" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#A6ADC8" FontSize="12"/>
                                    <ComboBox Name="ComboCheckerLang" Grid.Column="1" Width="120" Height="30" Background="#181825" Foreground="#CDD6F4" VerticalContentAlignment="Center">
                                        <ComboBoxItem Content="English (en)" IsSelected="True"/>
                                        <ComboBoxItem Content="한국어 (ko)"/>
                                    </ComboBox>
                                    <Button Name="BtnRunOfflineCheck" Grid.Column="3" Content="🚀 Run Offline Compatibility Check" Background="#89B4FA" Foreground="#11111B" FontWeight="Bold" FontSize="13" Padding="18,8"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Assessment Banner -->
                        <Border Name="BadgeStatusBorder" Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="2">
                            <StackPanel>
                                <TextBlock Name="TxtStatusHeader" Text="STATUS: AWAITING ANALYSIS" FontSize="15" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,4"/>
                                <TextBlock Name="TxtStatusSummary" Text="Select your capture directory above and click 'Run Offline Compatibility Check'." FontSize="13" Foreground="#CDD6F4" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                <Border Name="BorderNextStep" Background="#181825" CornerRadius="4" Padding="10" Margin="0,4,0,0" BorderBrush="#45475A" BorderThickness="1">
                                    <StackPanel>
                                        <TextBlock Text="Next Step Guidance:" FontWeight="Bold" FontSize="11" Foreground="#89DCEB" Margin="0,0,0,2"/>
                                        <TextBlock Name="TxtNextStep" Text="Run the check to see tailored recommendations." FontSize="12" Foreground="#A6ADC8" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Border>

                        <!-- Findings Views Switcher -->
                        <TabControl Name="FindingsTabControl" Height="260" Background="#181825" BorderBrush="#313244" BorderThickness="1" Margin="0,0,0,14">
                            <!-- Sub-Tab 1: Structured Findings -->
                            <TabItem Header="Structured Observations &amp; Checks">
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="12">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>

                                        <!-- Column 1: Captured Hardware & Firmware -->
                                        <StackPanel Grid.Column="0" Margin="0,0,8,0">
                                            <TextBlock Text="Hardware &amp; Firmware Observations" FontWeight="Bold" FontSize="13" Foreground="#F9E2AF" Margin="0,0,0,6"/>
                                            <TextBlock Name="TxtObsCaptures" Text="Captures Found: None" Margin="0,2" Foreground="#CDD6F4" FontSize="12"/>
                                            <TextBlock Name="TxtObsGpu" Text="Target GPU: Not detected" Margin="0,2" Foreground="#CDD6F4" FontSize="12"/>
                                            <TextBlock Name="TxtObsPciLoc" Text="PCI Bus / Location: Unknown" Margin="0,2" Foreground="#CDD6F4" FontSize="12"/>
                                            <TextBlock Name="TxtObsChip" Text="Chip / Memory: Unknown" Margin="0,2" Foreground="#CDD6F4" FontSize="12"/>
                                            <TextBlock Name="TxtObsNvgop" Text="Firmware NVGOP: Unknown" Margin="0,2" Foreground="#CDD6F4" FontSize="12"/>
                                            <TextBlock Name="TxtObsDisplays" Text="Display Controllers: Unknown" Margin="0,2" Foreground="#CDD6F4" FontSize="12"/>
                                        </StackPanel>

                                        <!-- Column 2: Evaluated Verification Checks -->
                                        <StackPanel Grid.Column="1" Margin="8,0,0,0">
                                            <TextBlock Text="Evaluated Engine Checks" FontWeight="Bold" FontSize="13" Foreground="#89B4FA" Margin="0,0,0,6"/>
                                            <TextBox Name="TxtChecksList" Height="150" Background="#11111B" Foreground="#CDD6F4" FontFamily="Consolas" FontSize="11" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" BorderThickness="0" Text="Checks will appear here after analysis."/>
                                        </StackPanel>
                                    </Grid>
                                </ScrollViewer>
                            </TabItem>

                            <!-- Sub-Tab 2: Raw JSON Report -->
                            <TabItem Header="Raw JSON Report">
                                <Grid Padding="6">
                                    <TextBox Name="TxtCaptureJson" Background="#11111B" Foreground="#A6E3A1" FontFamily="Consolas" FontSize="11" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="Wrap" BorderThickness="0" Text="Raw JSON report will be displayed here."/>
                                </Grid>
                            </TabItem>
                        </TabControl>

                        <!-- Report Actions -->
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                            <Button Name="BtnExportJson" Content="💾 Export Report JSON..." Margin="0,0,10,0"/>
                            <Button Name="BtnCopyClipboard" Content="📋 Copy JSON to Clipboard" Margin="0,0,10,0"/>
                        </StackPanel>

                        <!-- Expandable Report Comparison Suite -->
                        <Expander Header="⚖️ Compare Two Compatibility Reports (compare-compatibility.py)" Background="#252538" Foreground="#CDD6F4" Padding="10" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel Margin="0,8,0,0">
                                <TextBlock Text="Compare a reference report against your probe report to identify differences in GOP handles, EDID counts, or register states:" FontSize="11" Foreground="#A6ADC8" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                <Grid Margin="0,0,0,6">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Left (Reference):" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#CDD6F4" FontSize="11"/>
                                    <TextBox Name="TxtLeftReport" Grid.Column="1" Height="26" Background="#181825" Foreground="#CDD6F4" BorderBrush="#45475A" VerticalContentAlignment="Center" Padding="6,2"/>
                                    <Button Name="BtnBrowseLeftReport" Grid.Column="2" Content="Browse..." Margin="6,0,0,0" Padding="8,3"/>
                                </Grid>

                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Right (Probe):   " VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#CDD6F4" FontSize="11"/>
                                    <TextBox Name="TxtRightReport" Grid.Column="1" Height="26" Background="#181825" Foreground="#CDD6F4" BorderBrush="#45475A" VerticalContentAlignment="Center" Padding="6,2"/>
                                    <Button Name="BtnBrowseRightReport" Grid.Column="2" Content="Browse..." Margin="6,0,0,0" Padding="8,3"/>
                                </Grid>

                                <Button Name="BtnRunCompareReports" Content="⚖️ Compare Selected Reports" Background="#89B4FA" Foreground="#11111B" FontWeight="Bold" Padding="12,6" HorizontalAlignment="Left" Margin="0,0,0,8"/>
                                <TextBox Name="TxtCompareResult" Height="130" Background="#11111B" Foreground="#CDD6F4" FontFamily="Consolas" FontSize="11" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" BorderThickness="0" Text="Comparison differences will be displayed here."/>
                            </StackPanel>
                        </Expander>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 6: TELEMETRY & VERIFY -->
            <TabItem Header="Verification &amp; Telemetry">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="Live GPU Health &amp; Benchmark Uplift" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,10"/>
                        <TextBlock Text="After booting via the unlock bootloader, verify that the NVIDIA driver loaded cleanly and evaluate tensor throughput uplift using the cuBLAS benchmark." FontSize="12" Foreground="#A6ADC8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Live NVIDIA Telemetry:" FontWeight="Bold" FontSize="13" Foreground="#F9E2AF" Margin="0,0,0,8"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Name="TxtTelemName" Text="GPU: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                        <TextBlock Name="TxtTelemTemp" Text="Temperature: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                        <TextBlock Name="TxtTelemUtil" Text="Utilization: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                        <TextBlock Name="TxtTelemPower" Text="Power Draw: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1">
                                        <TextBlock Name="TxtTelemDriver" Text="Driver: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                        <TextBlock Name="TxtTelemMem" Text="VRAM Used: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                        <TextBlock Name="TxtTelemSmClock" Text="SM Clock: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                        <TextBlock Name="TxtTelemMemClock" Text="Memory Clock: Querying..." Margin="0,2" Foreground="#CDD6F4"/>
                                    </StackPanel>
                                </Grid>
                                <Button Name="BtnRefreshTelem" Content="Refresh Telemetry" Margin="0,10,0,0" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </Border>

                        <Border Background="#252538" CornerRadius="6" Padding="14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Expected Uplift Protocol (cuBLAS GEMM 4096 x 4096):" FontWeight="Bold" FontSize="13" Foreground="#89B4FA" Margin="0,0,0,6"/>
                                <TextBlock Text="* Locked Baseline: FP16 / BF16 Tensor compute is typically hardware throttled (~40-44 TFLOPS on GA104, ~65-70 on GA102)." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="* Unlocked State: FP16 / BF16 Tensor compute achieves full speed (~88 TFLOPS on 3070 Ti, ~125-130 TFLOPS on 3090) ~1.9x to 2.0x improvement." Foreground="#A6E3A1" Margin="0,2"/>
                                <TextBlock Text="* Unlock Verification: In unlock mode, selector SS0 is set to 0x88888888 and SS1 to 0x8." Foreground="#CDD6F4" Margin="0,2"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 7: EMERGENCY RECOVERY -->
            <TabItem Header="Emergency Recovery">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="16">
                    <StackPanel>
                        <TextBlock Text="One-Click Safety &amp; Emergency Recovery" FontSize="16" FontWeight="Bold" Foreground="#F38BA8" Margin="0,0,0,10"/>
                        <TextBlock Text="If your system fails to boot automatically or if you want to cleanly revert all EFI boot modifications back to stock Windows defaults, use this recovery module." FontSize="12" Foreground="#A6ADC8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                        <Border Background="#252538" CornerRadius="6" Padding="14" Margin="0,0,0,14" BorderBrush="#F38BA8" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="1-Click Revert: Restore Windows First Boot Priority" FontWeight="Bold" FontSize="14" Foreground="#F38BA8" Margin="0,0,0,6"/>
                                <TextBlock Text="Immediately writes Windows Boot Manager ({bootmgr}) as priority #1 in UEFI firmware displayorder and removes experimental sequences." FontSize="12" Foreground="#CDD6F4" Margin="0,0,0,10" TextWrapping="Wrap"/>
                                <Button Name="BtnEmergencyRestore" Content="Restore Windows Boot Manager (1-Click)" Background="#F38BA8" Foreground="#11111B" FontWeight="Bold" FontSize="13" Padding="16,10" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </Border>

                        <Border Background="#252538" CornerRadius="6" Padding="14" BorderBrush="#313244" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Troubleshooting Display Black Screen:" FontWeight="Bold" FontSize="13" Foreground="#F9E2AF" Margin="0,0,0,6"/>
                                <TextBlock Text="* If the screen remains black after booting: The GOP driver was removed and the card is waiting for Windows driver initialization. Wait 30 seconds." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="* If Windows does not appear: Power off completely by holding the power button for 5 seconds. Power back on and press F8/F12 to choose Windows Boot Manager directly." Foreground="#CDD6F4" Margin="0,2"/>
                                <TextBlock Text="* DisplayPort vs HDMI: DisplayPort 1.4 ports on GA102/GA104 cards have the highest recovery success rate." Foreground="#CDD6F4" Margin="0,2"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- BOTTOM CONSOLE / STATUS BAR -->
        <Border Grid.Row="2" Background="#1E1E2E" CornerRadius="6" Padding="12" Margin="0,14,0,0" BorderBrush="#313244" BorderThickness="1">
            <StackPanel>
                <Grid Margin="0,0,0,6">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Text="Activity &amp; Execution Log" FontSize="11" FontWeight="Bold" Foreground="#89B4FA"/>
                    <Button Name="BtnClearLog" Grid.Column="1" Content="Clear" Padding="6,2" FontSize="10"/>
                </Grid>
                <TextBox Name="TxtLog" Height="85" Background="#11111B" Foreground="#CDD6F4" FontFamily="Consolas" FontSize="11" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" BorderThickness="0"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

# --- LOAD WPF WINDOW ---

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Element References
$txtBadgeAdmin = $window.FindName('TxtBadgeAdmin')
$badgeAdmin = $window.FindName('BadgeAdmin')
$btnElevate = $window.FindName('BtnElevate')
$btnRefresh = $window.FindName('BtnRefresh')
$txtLog = $window.FindName('TxtLog')
$btnClearLog = $window.FindName('BtnClearLog')

# Tab 1
$txtAssessment = $window.FindName('TxtAssessment')
$txtBoard = $window.FindName('TxtBoard')
$txtBios = $window.FindName('TxtBios')
$txtCpu = $window.FindName('TxtCpu')
$txtOs = $window.FindName('TxtOs')
$txtGpuName = $window.FindName('TxtGpuName')
$txtGpuPci = $window.FindName('TxtGpuPci')
$txtGpuArch = $window.FindName('TxtGpuArch')
$txtGpuVram = $window.FindName('TxtGpuVram')
$txtGpuDriver = $window.FindName('TxtGpuDriver')

# Tab 2
$iconSecureBoot = $window.FindName('IconSecureBoot')
$txtDetailSecureBoot = $window.FindName('TxtDetailSecureBoot')
$iconFastStartup = $window.FindName('IconFastStartup')
$txtDetailFastStartup = $window.FindName('TxtDetailFastStartup')
$btnDisableFastStartup = $window.FindName('BtnDisableFastStartup')
$iconBitLocker = $window.FindName('IconBitLocker')
$txtDetailBitLocker = $window.FindName('TxtDetailBitLocker')
$iconAssets = $window.FindName('IconAssets')
$txtDetailAssets = $window.FindName('TxtDetailAssets')

# Tab 3
$comboUsbDrives = $window.FindName('ComboUsbDrives')
$btnRefreshUsb = $window.FindName('BtnRefreshUsb')
$btnDeployUsb = $window.FindName('BtnDeployUsb')

# Tab 4
$btnRunInternalConfigure = $window.FindName('BtnRunInternalConfigure')
$btnRestoreWindowsBcd = $window.FindName('BtnRestoreWindowsBcd')

# Tab 5 (Offline Compatibility Checker & Analyser)
$txtCaptureFolder = $window.FindName('TxtCaptureFolder')
$btnBrowseCaptureFolder = $window.FindName('BtnBrowseCaptureFolder')
$btnDetectUsbCaptures = $window.FindName('BtnDetectUsbCaptures')
$comboCheckerLang = $window.FindName('ComboCheckerLang')
$btnRunOfflineCheck = $window.FindName('BtnRunOfflineCheck')

$badgeStatusBorder = $window.FindName('BadgeStatusBorder')
$txtStatusHeader = $window.FindName('TxtStatusHeader')
$txtStatusSummary = $window.FindName('TxtStatusSummary')
$txtNextStep = $window.FindName('TxtNextStep')

$txtObsCaptures = $window.FindName('TxtObsCaptures')
$txtObsGpu = $window.FindName('TxtObsGpu')
$txtObsPciLoc = $window.FindName('TxtObsPciLoc')
$txtObsChip = $window.FindName('TxtObsChip')
$txtObsNvgop = $window.FindName('TxtObsNvgop')
$txtObsDisplays = $window.FindName('TxtObsDisplays')
$txtChecksList = $window.FindName('TxtChecksList')
$txtCaptureJson = $window.FindName('TxtCaptureJson')

$btnExportJson = $window.FindName('BtnExportJson')
$btnCopyClipboard = $window.FindName('BtnCopyClipboard')

$txtLeftReport = $window.FindName('TxtLeftReport')
$btnBrowseLeftReport = $window.FindName('BtnBrowseLeftReport')
$txtRightReport = $window.FindName('TxtRightReport')
$btnBrowseRightReport = $window.FindName('BtnBrowseRightReport')
$btnRunCompareReports = $window.FindName('BtnRunCompareReports')
$txtCompareResult = $window.FindName('TxtCompareResult')

# Tab 6
$txtTelemName = $window.FindName('TxtTelemName')
$txtTelemTemp = $window.FindName('TxtTelemTemp')
$txtTelemUtil = $window.FindName('TxtTelemUtil')
$txtTelemPower = $window.FindName('TxtTelemPower')
$txtTelemDriver = $window.FindName('TxtTelemDriver')
$txtTelemMem = $window.FindName('TxtTelemMem')
$txtTelemSmClock = $window.FindName('TxtTelemSmClock')
$txtTelemMemClock = $window.FindName('TxtTelemMemClock')
$btnRefreshTelem = $window.FindName('BtnRefreshTelem')

# Tab 7
$btnEmergencyRestore = $window.FindName('BtnEmergencyRestore')

# Stored Last Report
$Script:LastAnalysis = $null

# --- LOGGING HELPER ---
function Write-GuiLog([string]$Msg) {
    $time = [DateTime]::Now.ToString("HH:mm:ss")
    $txtLog.AppendText("[$time] $Msg`r`n")
    $txtLog.ScrollToEnd()
}

# --- EVENT HANDLERS & REFRESH LOGIC ---

function Refresh-AuditData {
    Write-GuiLog "Scanning host hardware and GPU identities..."
    $info = Get-GpuHardwareInfo
    $txtAssessment.Text = $info['ProfileAssessment']
    $txtBoard.Text = "Motherboard: $($info['Motherboard'])"
    $txtBios.Text = "BIOS Version: $($info['BIOS'])"
    $txtCpu.Text = "Processor: $($info['CPU'])"
    $txtOs.Text = "Operating System: $($info['OS'])"

    $gpu = $info['GPUs'] | Where-Object { $_.IsAmpere } | Select-Object -First 1
    if (-not $gpu -and $info['GPUs'].Count -gt 0) { $gpu = $info['GPUs'][0] }

    if ($gpu) {
        $txtGpuName.Text = "GPU: $($gpu.Name)"
        $txtGpuPci.Text = "PCI VEN/DEV: $($gpu.PCI.Vendor):$($gpu.PCI.Device) (Subsystem: $($gpu.PCI.SubsystemVendor):$($gpu.PCI.SubsystemDevice))"
        $txtGpuArch.Text = "Architecture: $($gpu.Architecture)"
        $txtGpuVram.Text = "VRAM: $($gpu.VramMb) MB"
        $txtGpuDriver.Text = "Driver Version: $($gpu.DriverVersion)"
    } else {
        $txtGpuName.Text = "GPU: No compatible GPU detected."
    }
}

function Refresh-PreflightData {
    Write-GuiLog "Evaluating system safety and prerequisites..."
    $checks = Get-PreflightChecks

    # Secure Boot
    $sb = $checks['SecureBoot']
    $txtDetailSecureBoot.Text = $sb.Detail
    if ($sb.Status -eq 'PASS') {
        $iconSecureBoot.Text = "[OK]"; $iconSecureBoot.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } elseif ($sb.Status -eq 'FAIL') {
        $iconSecureBoot.Text = "[X]"; $iconSecureBoot.Foreground = [System.Windows.Media.Brushes]::Tomato
    } else {
        $iconSecureBoot.Text = "[!]"; $iconSecureBoot.Foreground = [System.Windows.Media.Brushes]::Gold
    }

    # Fast Startup
    $fs = $checks['FastStartup']
    $txtDetailFastStartup.Text = $fs.Detail
    if ($fs.Status -eq 'PASS') {
        $iconFastStartup.Text = "[OK]"; $iconFastStartup.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $btnDisableFastStartup.Visibility = [System.Windows.Visibility]::Collapsed
    } elseif ($fs.Status -eq 'WARN') {
        $iconFastStartup.Text = "[!]"; $iconFastStartup.Foreground = [System.Windows.Media.Brushes]::Gold
        $btnDisableFastStartup.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $iconFastStartup.Text = "[?]"; $iconFastStartup.Foreground = [System.Windows.Media.Brushes]::Gray
    }

    # BitLocker
    $bl = $checks['BitLocker']
    $txtDetailBitLocker.Text = $bl.Detail
    if ($bl.Status -eq 'PASS') {
        $iconBitLocker.Text = "[OK]"; $iconBitLocker.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } elseif ($bl.Status -eq 'WARN') {
        $iconBitLocker.Text = "[!]"; $iconBitLocker.Foreground = [System.Windows.Media.Brushes]::Tomato
    } else {
        $iconBitLocker.Text = "[i]"; $iconBitLocker.Foreground = [System.Windows.Media.Brushes]::SkyBlue
    }

    # Assets & Binary
    $as = $checks['FirmwareAssets']
    $rel = $checks['ReleaseEFI']
    $txtDetailAssets.Text = "$($rel.Detail)`n$($as.Detail)"
    if ($as.Status -eq 'PASS' -and $rel.Status -eq 'PASS') {
        $iconAssets.Text = "[OK]"; $iconAssets.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } else {
        $iconAssets.Text = "[!]"; $iconAssets.Foreground = [System.Windows.Media.Brushes]::Gold
    }
}

function Refresh-UsbList {
    $comboUsbDrives.Items.Clear()
    $drives = Get-RemovableDrives
    if ($drives.Count -eq 0) {
        $comboUsbDrives.Items.Add("No removable USB drive detected") | Out-Null
        $comboUsbDrives.SelectedIndex = 0
    } else {
        foreach ($d in $drives) {
            $comboUsbDrives.Items.Add("$($d.DriveLetter) [$($d.FileSystem), $($d.SizeGb) GB] $($d.FriendlyName)") | Out-Null
        }
        $comboUsbDrives.SelectedIndex = 0
    }
}

function Refresh-TelemetryData {
    $telem = Get-GpuTelemetryLive
    if ($telem['Error']) {
        $txtTelemName.Text = "GPU: $($telem['Error'])"
    } else {
        $txtTelemName.Text = "GPU: $($telem['Name'])"
        $txtTelemTemp.Text = "Temperature: $($telem['TempC']) deg C"
        $txtTelemUtil.Text = "Utilization: $($telem['UtilGpu'])"
        $txtTelemPower.Text = "Power Draw: $($telem['PowerDrawW']) / $($telem['PowerLimitW'])"
        $txtTelemDriver.Text = "Driver: $($telem['Driver'])"
        $txtTelemMem.Text = "VRAM: $($telem['MemUsedMb']) / $($telem['MemTotalMb'])"
        $txtTelemSmClock.Text = "SM Clock: $($telem['ClockSmMhz'])"
        $txtTelemMemClock.Text = "Memory Clock: $($telem['ClockMemMhz'])"
    }
}

function Update-CompatibilityResultsView($res) {
    $Script:LastAnalysis = $res

    # Status & Badge
    $txtStatusHeader.Text = $res.Badge
    $txtStatusSummary.Text = $res.Summary
    $txtNextStep.Text = $res.NextStep

    $badgeBrush = switch ($res.Status) {
        'candidate'     { [System.Windows.Media.Brushes]::LightGreen }
        'needs_data'    { [System.Windows.Media.Brushes]::Gold }
        'outside_scope' { [System.Windows.Media.Brushes]::DarkOrange }
        'invalid_data'  { [System.Windows.Media.Brushes]::Tomato }
        default         { [System.Windows.Media.Brushes]::Gray }
    }
    $badgeStatusBorder.BorderBrush = $badgeBrush
    $txtStatusHeader.Foreground = $badgeBrush

    # Observations breakdown
    $txtObsCaptures.Text = "Captures Found: $($res.CaptureCount) valid DIAG capture(s)"

    if ($res.Observations -and $res.Observations.Count -gt 0) {
        $obs = $res.Observations[0]
        $gpuText = "Unknown"
        if ($obs.adapters -and $obs.adapters.Count -gt 0) {
            $ad = $obs.adapters[0]
            $gpuText = "PCI: $($ad.pci_id) (Subsys: $($ad.subsystem_id), Class: $($ad.class_revision))"
            if ($ad.location) {
                $txtObsPciLoc.Text = "Location: Seg $($ad.location.segment), Bus $($ad.location.bus), Dev $($ad.location.device), Func $($ad.location.function)"
            }
        }
        $txtObsGpu.Text = "Target GPU: $gpuText"
        $txtObsChip.Text = "Chip ID: $(if ($obs.chip_id) { $obs.chip_id } else { 'null' }) | Memory: $(if ($obs.device_memory_size_mib) { $obs.device_memory_size_mib + ' MiB' } else { 'null' })"
        $txtObsDisplays.Text = "Displays: $($obs.nvidia_display_count) NVIDIA, $($obs.other_display_count) Other (GOP Handles: $($obs.gop_handle_count))"
        $txtObsNvgop.Text = "NVGOP Bindings: $(if ($obs.firmware_bindings) { $obs.firmware_bindings.Count } else { 0 }) observed"
    } else {
        $txtObsGpu.Text = "Target GPU: No observations recorded"
        $txtObsPciLoc.Text = "Location: N/A"
        $txtObsChip.Text = "Chip / Memory: N/A"
        $txtObsDisplays.Text = "Displays: N/A"
        $txtObsNvgop.Text = "NVGOP Bindings: N/A"
    }

    # Itemized Checks
    $chkLines = @()
    foreach ($chk in $res.Checks) {
        $chkLines += "[$($chk.state.ToUpper())] $($chk.code): $($chk.message)"
    }
    if ($chkLines.Count -eq 0) {
        $txtChecksList.Text = "No individual check codes reported."
    } else {
        $txtChecksList.Text = ($chkLines -join "`r`n")
    }

    # Raw JSON
    $txtCaptureJson.Text = $res.RawJson
}

# --- INITIALIZE UI STATE ---
$isAdmin = Test-IsAdmin
if ($isAdmin) {
    $txtBadgeAdmin.Text = "ADMINISTRATOR"
    $badgeAdmin.Background = [System.Windows.Media.Brushes]::LightGreen
    $btnElevate.Visibility = [System.Windows.Visibility]::Collapsed
} else {
    $txtBadgeAdmin.Text = "USER MODE"
    $badgeAdmin.Background = [System.Windows.Media.Brushes]::Gold
    $btnElevate.Visibility = [System.Windows.Visibility]::Visible
}

# --- EVENT HOOKS ---

$btnElevate.Add_Click({
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        $window.Close()
    } catch {
        Write-GuiLog "Elevation request was cancelled."
    }
})

$btnRefresh.Add_Click({
    Refresh-AuditData
    Refresh-PreflightData
    Refresh-UsbList
    Refresh-TelemetryData
    Write-GuiLog "Refreshed all system, safety, and telemetry data."
})

$btnClearLog.Add_Click({ $txtLog.Clear() })

$btnDisableFastStartup.Add_Click({
    try {
        $msg = Disable-WindowsFastStartup
        Write-GuiLog $msg
        Refresh-PreflightData
        [System.Windows.MessageBox]::Show($msg, "Fast Startup Disabled", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        Write-GuiLog "Error disabling Fast Startup: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
})

$btnRefreshUsb.Add_Click({
    Refresh-UsbList
    Write-GuiLog "Refreshed connected removable USB drive list."
})

$btnDeployUsb.Add_Click({
    $selected = [string]$comboUsbDrives.SelectedItem
    if (-not $selected -or $selected.StartsWith("No removable")) {
        [System.Windows.MessageBox]::Show("Please connect a FAT32 USB drive first.", "No USB Selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    $letter = $selected.Substring(0, 1)
    $confirm = [System.Windows.MessageBox]::Show("Stage UEFI Unlock files onto drive $letter`:`\?`n`nThis will copy BOOTX64.EFI and firmware assets into FAT32 directories.`nExisting files will be preserved.", "Confirm USB Deployment", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Write-GuiLog "Starting USB deployment to $letter`:..."
            $res = Deploy-ToUsb $letter
            Write-GuiLog "Staging complete: $($res.Status) (Assets copied: $($res.AssetsCopied))"
            [System.Windows.MessageBox]::Show("USB Unlock deployed successfully to $letter`:`\!`n`nReboot your PC and press your Boot Menu key (ASUS F8 / Gigabyte F12 / MSI F11) to boot.", "Deployment Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        } catch {
            Write-GuiLog "USB deployment error: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show($_.Exception.Message, "Deployment Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    }
})

$btnRunInternalConfigure.Add_Click({
    Write-GuiLog "Internal Headless Setup requires manual execution with exact GUID of dedicated ESP."
    [System.Windows.MessageBox]::Show("To configure Internal Headless ESP, run from Administrator PowerShell:`n`n.\internal-boot\Configure.ps1 -UnlockDriveLetter U -WindowsEspGuid <GUID>`n`nEnsure you use a dedicated secondary ESP partition, never the Windows ESP.", "Internal ESP Instructions", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
})

$btnRestoreWindowsBcd.Add_Click({
    try {
        Write-GuiLog "Restoring default Windows Boot Manager priority..."
        $msg = Restore-WindowsFirstBootOrder
        Write-GuiLog $msg
        [System.Windows.MessageBox]::Show("Windows Boot Manager has been restored as primary boot entry.", "Boot Order Restored", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        Write-GuiLog "Error restoring boot order: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Restore Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
})

$btnEmergencyRestore.Add_Click({
    $btnRestoreWindowsBcd.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
})

# --- OFFLINE CHECKER TAB EVENT HANDLERS ---

$btnBrowseCaptureFolder.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select Folder Containing Diagnostic Captures (DIAGnn.TXT)"
    if (Test-Path -LiteralPath $txtCaptureFolder.Text) {
        $dialog.SelectedPath = $txtCaptureFolder.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtCaptureFolder.Text = $dialog.SelectedPath
        Write-GuiLog "Selected capture folder: $($dialog.SelectedPath)"
    }
})

$btnDetectUsbCaptures.Add_Click({
    Write-GuiLog "Searching for EFI capture folders on connected USB drives..."
    $candidates = Find-UsbCaptureFolders
    if ($candidates.Count -gt 0) {
        $txtCaptureFolder.Text = $candidates[0]
        Write-GuiLog "Found capture folder on USB: $($candidates[0])"
        [System.Windows.MessageBox]::Show("Found capture folder on USB drive:`n$($candidates[0])", "USB Captures Located", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } else {
        Write-GuiLog "No capture folders found on USB drives."
        [System.Windows.MessageBox]::Show("No capture folders or DIAG*.TXT files found on connected USB drives.`n`nIf you already booted from USB, ensure the USB stick is plugged in.", "No Captures Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    }
})

$btnRunOfflineCheck.Add_Click({
    $folder = $txtCaptureFolder.Text.Trim()
    if (-not $folder) {
        [System.Windows.MessageBox]::Show("Please specify or browse to a capture folder.", "Missing Folder", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $langSelected = if ($comboCheckerLang.SelectedIndex -eq 1) { 'ko' } else { 'en' }
    try {
        Write-GuiLog "Running offline compatibility checker on: $folder (Lang: $langSelected)..."
        $txtStatusHeader.Text = "ANALYZING..."
        $txtStatusHeader.Foreground = [System.Windows.Media.Brushes]::Gold
        $txtStatusSummary.Text = "Reading diagnostic captures, driver images, and PROM..."

        $res = Invoke-OfflineCompatibilityCheck -Folder $folder -Language $langSelected
        Update-CompatibilityResultsView $res
        Write-GuiLog "Offline check complete: $($res.Badge)"
    } catch {
        Write-GuiLog "Error during offline check: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Checker Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
})

$btnExportJson.Add_Click({
    if (-not $Script:LastAnalysis -or -not $Script:LastAnalysis.RawJson) {
        [System.Windows.MessageBox]::Show("Run an offline compatibility check first to generate a report.", "No Report to Export", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "JSON Report (*.json)|*.json|All Files (*.*)|*.*"
    $dialog.FileName = "compatibility-report.json"
    $dialog.Title = "Save Compatibility Report JSON"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            Set-Content -LiteralPath $dialog.FileName -Value $Script:LastAnalysis.RawJson -Encoding utf8
            Write-GuiLog "Saved compatibility report JSON to: $($dialog.FileName)"
            [System.Windows.MessageBox]::Show("Compatibility report saved to:`n$($dialog.FileName)", "Report Exported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        } catch {
            Write-GuiLog "Failed to export report: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show($_.Exception.Message, "Export Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    }
})

$btnCopyClipboard.Add_Click({
    if (-not $Script:LastAnalysis -or -not $Script:LastAnalysis.RawJson) {
        [System.Windows.MessageBox]::Show("Run an offline compatibility check first to generate a report.", "No Report to Copy", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    try {
        [System.Windows.Forms.Clipboard]::SetText($Script:LastAnalysis.RawJson)
        Write-GuiLog "Copied compatibility report JSON to clipboard."
        [System.Windows.MessageBox]::Show("Compatibility report JSON copied to clipboard!`n`nYou can paste it directly into the GitHub Issue report form.", "Copied to Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        Write-GuiLog "Failed to copy to clipboard: $($_.Exception.Message)"
    }
})

$btnBrowseLeftReport.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "JSON Reports (*.json)|*.json|All Files (*.*)|*.*"
    $dialog.Title = "Select Reference Compatibility Report JSON"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLeftReport.Text = $dialog.FileName
    }
})

$btnBrowseRightReport.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "JSON Reports (*.json)|*.json|All Files (*.*)|*.*"
    $dialog.Title = "Select Probe Compatibility Report JSON"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtRightReport.Text = $dialog.FileName
    }
})

$btnRunCompareReports.Add_Click({
    $left = $txtLeftReport.Text.Trim()
    $right = $txtRightReport.Text.Trim()
    if (-not $left -or -not $right) {
        [System.Windows.MessageBox]::Show("Please select both a reference (Left) and a probe (Right) JSON report file.", "Missing Reports", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    try {
        Write-GuiLog "Comparing reports: $left vs $right..."
        $txtCompareResult.Text = "Running compare-compatibility.py..."
        $diff = Invoke-CompareCompatibilityReports -LeftReportPath $left -RightReportPath $right
        $txtCompareResult.Text = $diff
        Write-GuiLog "Report comparison finished."
    } catch {
        $txtCompareResult.Text = "Comparison Error: $($_.Exception.Message)"
        Write-GuiLog "Comparison error: $($_.Exception.Message)"
    }
})

$btnRefreshTelem.Add_Click({
    Refresh-TelemetryData
    Write-GuiLog "Refreshed live GPU telemetry."
})

# Load Initial Data
Refresh-AuditData
Refresh-PreflightData
Refresh-UsbList
Refresh-TelemetryData
Write-GuiLog "GPU Unlock Utility ready. Welcome!"

# Show Dialog
$window.ShowDialog() | Out-Null
