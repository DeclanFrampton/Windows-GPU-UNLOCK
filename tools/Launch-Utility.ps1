<#
.SYNOPSIS
    Convenience launcher for the Windows GPU UNLOCK Utility.
#>
[CmdletBinding()]
param(
    [switch]$Cli,
    [string]$Action = 'Audit'
)

$script = Join-Path $PSScriptRoot "tools\gpu_unlock_utility\GpuUnlockUtility.ps1"
if (-not (Test-Path -LiteralPath $script)) {
    Write-Error "Could not find GpuUnlockUtility.ps1 at $script"
    exit 1
}

if ($Cli) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script -Cli -Action $Action
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script
}

