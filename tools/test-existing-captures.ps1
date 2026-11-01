# Offline only: reads existing files, never starts EFI or accesses GPU hardware.
[CmdletBinding()]
param([string]$Captures)
$ErrorActionPreference = 'Stop'
if (!$Captures) { $Captures = Read-Host 'Enter the folder containing your existing DIAG00.TXT / DIAG01.TXT' }
$source = (Resolve-Path -LiteralPath $Captures).Path
if (!(Test-Path -LiteralPath $source -PathType Container)) { throw 'Select a folder, not a file.' }
$root = Split-Path -Parent $PSScriptRoot
$python = Get-Command python.exe -ErrorAction Stop
$documents = [Environment]::GetFolderPath('MyDocuments')
if (!$documents) { throw 'Documents folder is unavailable.' }
$output = Join-Path $documents ('GPU-Unlock-Capture-Check-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $output | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$result = [ordered]@{ test = 'existing-capture-refusal-v1'; checker_exit = $null; status = 'FAILED' }
$process = New-Object System.Diagnostics.Process
try {
    $process.StartInfo.FileName = $python.Source
    # Windows filenames cannot contain a quote. The folder is one quoted argument.
    $process.StartInfo.Arguments = '-I research/profile/check-compatibility.py "' + (Join-Path $source '.') + '" --json'
    $process.StartInfo.WorkingDirectory = $root
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.StandardOutputEncoding = $utf8
    $process.StartInfo.StandardErrorEncoding = $utf8
    if (!$process.Start()) { throw 'Python did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit(120000)) { $process.Kill(); throw 'Offline check timed out.' }
    $result.checker_exit = $process.ExitCode
    if ($process.ExitCode -notin @(0, 2, 3)) { throw 'Checker failed.' }
    $report = $stdout.Result | ConvertFrom-Json
    if ($report.route -ne 'automatic_local_profile' -or $report.write_eligible -ne $false -or
        $report.hardware_tested -ne $false) { throw 'Unexpected report.' }
    [IO.File]::WriteAllText((Join-Path $output 'report.json'), $stdout.Result, $utf8)
    $result.status = $report.status
    Write-Host ('Report status: ' + $report.status)
    foreach ($check in $report.checks) { Write-Host ($check.capture + ': ' + $check.code) }
} catch {
    Write-Host 'The offline check failed. Send result.json; do not collect new EFI logs.'
} finally {
    $process.Dispose()
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json), $utf8)
}
Write-Host ('Results folder: ' + $output)
Write-Host 'Review and attach report.json (if present) and result.json to your existing issue.'
Write-Host 'A refusal remains refused. Do not reboot, change settings or force another profile.'
if ($result.status -eq 'FAILED') { exit 1 }
exit 0
