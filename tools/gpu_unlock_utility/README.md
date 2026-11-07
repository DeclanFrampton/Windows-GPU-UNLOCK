# Windows GPU UNLOCK - Management & Deployment Utility

A unified, executive Windows GUI and CLI application for the **Windows-GPU-UNLOCK** project. Designed to simplify hardware assessment, safety checks, USB unlock staging, BCD configuration, offline diagnostic analysis, live telemetry, and emergency system recovery.

---

## Key Features

1. **🖥️ Hardware & GPU Compatibility Audit**
   - Automatically detects GPU model, PCI VEN/DEV, Subsystem vendor/device, VRAM, and driver version.
   - Identifies NVIDIA Ampere architectures (`GA102`, `GA104`, `GA106`) across RTX 3060, 3070, 3070 Ti, 3080, 3090, 3090 Ti.
   - Evaluates hardware against known fixed profiles (`b650m-3090fe`, `b660m-3070ti`, `x870-3090ti`, `b660plus-3060`, `h610m-3060`, `b660m-3090ti`) or qualifies for the generic/local USB route.

2. **🛡️ Pre-Flight Safety & Prerequisite Verification**
   - **Secure Boot**: Checks if disabled (required for unsigned EFI bootloader execution).
   - **BitLocker Protection**: Audits C: protection state to prevent bootloader recovery key lockouts.
   - **Windows Fast Startup**: Audits hybrid sleep (`HiberbootEnabled`) and provides a 1-click disable button.
   - **Asset Integrity**: Validates the presence and SHA-256 hashes of the required firmware assets against `unlock/assets.json`.
   - **Binary Integrity**: Validates pre-compiled `release/EFI/BOOT/BOOTX64.EFI` against `provenance.json`.

3. **💾 USB Unlock Stager (Headless USB Route)**
   - Scans for connected removable FAT32 storage devices.
   - 1-click staging of `BOOTX64.EFI` to `\EFI\BOOT\` and firmware assets to `\RTX3090-UNLOCK\ASSETS\`.
   - Provides motherboard-specific one-time boot menu keys (ASUS `F8`, Gigabyte `F12`, MSI `F11`, ASRock `F11`).

4. **⚙️ Internal ESP & BCD Manager**
   - Detects secondary dedicated GPT FAT32 ESP partitions.
   - Coordinates with `internal-boot/Configure.ps1` and `Headless.ps1`.
   - Manages UEFI BCD boot priorities.

5. **🔍 Offline Capture Analyzer**
   - Inspects existing diagnostic dumps (`DIAGnn.TXT`, `IMGnn.BIN`, `PROM.BIN`).
   - Seamlessly invokes `research/profile/check-compatibility.py` and presents human-readable results.

6. **⚡ Live Telemetry & Verification**
   - Real-time GPU telemetry via `nvidia-smi` (clock speeds, temperature, power draw, VRAM).
   - Guidance on cuBLAS GEMM 4096 benchmark verification protocol (measuring the expected ~1.9x to 2.0x tensor throughput uplift post-unlock).

7. **🚨 One-Click Emergency Recovery**
   - Instantly restores Windows Boot Manager (`{bootmgr}`) as priority #1 in UEFI NVRAM (`{fwbootmgr}`).
   - Safe revert with zero risk of boot lockout.

---

## How to Launch

### Option 1: Direct Double-Click (Batch Launcher)
Double-click `Launch-Utility.cmd` in the repository root. It detects your permissions and prompts for Administrator elevation if desired.

### Option 2: PowerShell Launcher
```powershell
.\Launch-Utility.ps1
```

### Option 3: Command-Line (CLI) Automation
For automated scripts or headless environments, use the `-Cli` flag:

```powershell
# Run hardware compatibility audit
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action Audit

# Run safety pre-flight check
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action Preflight

# Check connected USB storage devices
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CheckUsb

# Query live GPU telemetry
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action Telemetry

# Stage unlock payload to a FAT32 USB drive (e.g. drive E:)
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action DeployUsb -DriveLetter E

# Restore Windows Boot Manager priority in BCD
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action RestoreWindows

# Analyze an existing offline capture directory
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CheckCaptures -CapturePath "D:\captures"
```

