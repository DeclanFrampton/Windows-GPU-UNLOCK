# Windows GPU UNLOCK - Management & Deployment Utility

A unified, executive Windows GUI and CLI application for the **Windows-GPU-UNLOCK** project. Designed to simplify hardware assessment, safety checks, offline compatibility checking and capture analysis, report comparisons, USB unlock staging, BCD configuration, live telemetry, and emergency system recovery.

---

## Key Features

1. **🔍 Offline Compatibility Checker & Analyser**
   - **Pre-boot Capture Analysis**: Safely inspects diagnostic dumps (`DIAGnn.TXT`, `IMGnn.BIN`, `PROM.BIN`) without touching running hardware or modifying boot configurations.
   - **Multi-Engine Evaluation**: Integrates directly with `research/profile/check-compatibility.py`.
   - **Visual Assessment Badging**: Displays clear determination badges:
     - `[CANDIDATE]` (Eligible for local profile generation)
     - `[NEEDS DATA]` (Missing captures or firmware dump files)
     - `[OUTSIDE SCOPE]` (GPU or display topology outside reviewed envelope)
     - `[INVALID DATA]` (Inconsistent or corrupted observations)
   - **Itemized Checks Breakdown**: Lists all individual check results (`observations_pass`, `images_pass`, `prom_pass`, etc.) with status pills.
   - **Hardware & Firmware Observations**: Summarizes capture count, target GPU PCI IDs, BDF location, chip/memory size, NVGOP binding versions, and display controller topology.
   - **Auto-Detection on USB**: 1-click scan across all connected USB drives to find EFI capture folders (`RTX3090-UNLOCK` or root `DIAG*.TXT`).
   - **1-Click Export & Clipboard**: Export standard Format-2 JSON reports to file or copy to clipboard for GitHub issue submission.
   - **Report Comparison Tool**: Built-in comparator (`compare-compatibility.py`) to compare reference vs probe reports side-by-side (`same`, `different`, `unavailable`).

2. **🖥️ Hardware & GPU Compatibility Audit**
   - Automatically detects GPU model, PCI VEN/DEV, Subsystem vendor/device, VRAM, and driver version.
   - Identifies NVIDIA Ampere architectures (`GA102`, `GA104`, `GA106`) across RTX 3060, 3070, 3070 Ti, 3080, 3090, 3090 Ti.
   - Evaluates hardware against known fixed profiles (`b650m-3090fe`, `b660m-3070ti`, `x870-3090ti`, `b660plus-3060`, `h610m-3060`, `b660m-3090ti`) or qualifies for the generic/local USB route.

3. **🛡️ Pre-Flight Safety & Prerequisite Verification**
   - **Secure Boot**: Checks if disabled (required for unsigned EFI bootloader execution).
   - **BitLocker Protection**: Audits C: protection state to prevent bootloader recovery key lockouts.
   - **Windows Fast Startup**: Audits hybrid sleep (`HiberbootEnabled`) and provides a 1-click disable button.
   - **Asset Integrity**: Validates the presence and SHA-256 hashes of the required firmware assets against `unlock/assets.json`.
   - **Binary Integrity**: Validates pre-compiled `release/EFI/BOOT/BOOTX64.EFI` against `provenance.json`.

4. **💾 USB Unlock Stager (Headless USB Route)**
   - Scans for connected removable FAT32 storage devices.
   - 1-click staging of `BOOTX64.EFI` to `\EFI\BOOT\` and firmware assets to `\RTX3090-UNLOCK\ASSETS\`.
   - Provides motherboard-specific one-time boot menu keys (ASUS `F8`, Gigabyte `F12`, MSI `F11`, ASRock `F11`).

5. **⚙️ Internal ESP & BCD Manager**
   - Detects secondary dedicated GPT FAT32 ESP partitions.
   - Coordinates with `internal-boot/Configure.ps1` and `Headless.ps1`.
   - Manages UEFI BCD boot priorities.

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
For automated scripts, test runners, or headless environments, use the `-Cli` flag:

```powershell
# 1. Run offline compatibility check on a capture folder (Human-readable summary)
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CheckCaptures -CapturePath "D:\RTX3090-UNLOCK"

# 2. Run offline compatibility check with Korean explanation
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CheckCaptures -CapturePath "D:\RTX3090-UNLOCK" -Lang ko

# 3. Output pure JSON report and export to file
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CheckCaptures -CapturePath "D:\RTX3090-UNLOCK" -Json -ExportPath ".\report.json"

# 4. Compare two compatibility report JSON files
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CompareReports -LeftReport ".\ref.json" -RightReport ".\probe.json"

# 5. Run hardware compatibility audit
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action Audit

# 6. Run safety pre-flight checks
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action Preflight

# 7. Check connected USB storage devices
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action CheckUsb

# 8. Query live GPU telemetry
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action Telemetry

# 9. Stage unlock payload to a FAT32 USB drive (e.g. drive E:)
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action DeployUsb -DriveLetter E

# 10. Restore Windows Boot Manager priority in BCD
.\tools\gpu_unlock_utility\GpuUnlockUtility.ps1 -Cli -Action RestoreWindows
```
