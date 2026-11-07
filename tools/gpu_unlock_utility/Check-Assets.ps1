<#
.SYNOPSIS
    Firmware Asset Verifier and Importer for Windows GPU UNLOCK
.DESCRIPTION
    Checks the local 'assets/' folder against unlock/assets.json SHA-256 specifications.
    Can also scan an external folder (e.g. downloads) to import and verify matching files.
.PARAMETER ImportFrom
    Optional path to a folder containing candidate firmware .bin files to inspect and import.
#>
param(
    [string]$ImportFrom
)

$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$assetsJson = Join-Path $repo 'unlock\assets.json'
$assetsDir = Join-Path $repo 'assets'

if (-not (Test-Path -LiteralPath $assetsJson)) {
    Write-Error "assets.json missing from $assetsJson"
    exit 1
}

$specs = Get-Content -LiteralPath $assetsJson -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Windows GPU UNLOCK - Firmware Asset Verifier" -ForegroundColor White
Write-Host " Target Directory: $assetsDir" -ForegroundColor DarkGray
Write-Host "========================================================`n" -ForegroundColor Cyan

# Optional Import
if ($ImportFrom) {
    if (Test-Path -LiteralPath $ImportFrom) {
        Write-Host "[*] Scanning '$ImportFrom' for candidate asset files..." -ForegroundColor Yellow
        $imported = 0
        foreach ($spec in $specs) {
            $candidate = Join-Path $ImportFrom $spec.Name
            if (Test-Path -LiteralPath $candidate) {
                $hash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
                $len = (Get-Item -LiteralPath $candidate).Length
                if ($hash -eq $spec.Sha256.ToLowerInvariant() -and $len -eq $spec.Bytes) {
                    Copy-Item -LiteralPath $candidate -Destination (Join-Path $assetsDir $spec.Name) -Force
                    Write-Host "  -> Imported and verified: $($spec.Name)" -ForegroundColor Green
                    $imported++
                } else {
                    Write-Host "  -> File '$($spec.Name)' found but hash/size mismatch. Skipped." -ForegroundColor DarkYellow
                }
            }
        }
        Write-Host "[*] Imported $imported matching asset file(s).`n" -ForegroundColor Yellow
    } else {
        Write-Warning "Import folder '$ImportFrom' does not exist."
    }
}

# Verify Current Assets
$verifiedCount = 0
$totalCount = $specs.Count

foreach ($spec in $specs) {
    $targetFile = Join-Path $assetsDir $spec.Name
    if (Test-Path -LiteralPath $targetFile) {
        $item = Get-Item -LiteralPath $targetFile
        $hash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($item.Length -eq $spec.Bytes -and $hash -eq $spec.Sha256.ToLowerInvariant()) {
            Write-Host "[PASS] $($spec.Name) (Size: $($item.Length) bytes, SHA256 matched)" -ForegroundColor Green
            $verifiedCount++
        } else {
            Write-Host "[FAIL] $($spec.Name) (Checksum or size mismatch)" -ForegroundColor Red
            Write-Host "       Expected: $($spec.Bytes) bytes, $($spec.Sha256)" -ForegroundColor DarkGray
            Write-Host "       Found:    $($item.Length) bytes, $hash" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "[MISS] $($spec.Name) (Not present in assets/)" -ForegroundColor DarkYellow
    }
}

Write-Host "`n--------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Summary: $verifiedCount of $totalCount firmware assets verified." -ForegroundColor $(if ($verifiedCount -eq $totalCount) { 'Green' } else { 'Yellow' })
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan

if ($verifiedCount -lt $totalCount) {
    Write-Host "`nTo acquire missing assets:" -ForegroundColor White
    Write-Host "1. Follow docs/ASSETS.en.md to generate assets using the upstream Zagitta/gpu-unlock tool."
    Write-Host "2. Once generated, run: .\tools\gpu_unlock_utility\Check-Assets.ps1 -ImportFrom <folder_with_assets>"
}

