# Offline source/documentation checks; does not change or exercise execution policy.
$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'test-collector.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Collector launcher did not parse.' }
$commands = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
foreach ($forbidden in @('Set-ExecutionPolicy', 'Unblock-File', 'Add-MpPreference', 'Set-MpPreference')) {
    if ($commands -icontains $forbidden) { throw "Forbidden policy/security mutation: $forbidden" }
}
$source = [IO.File]::ReadAllText($path)
if ($source -match '(?i)-ExecutionPolicy\s+(?:Bypass|Unrestricted)' -or $source -match '(?i)FromBase64String|EncodedCommand') { throw 'Unexpected alternate execution route.' }
$docs = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../docs/COLLECTOR-TEST.en.md'))
foreach ($phrase in @('If execution policy blocks the script', 'no result.json', 'no established trusted publisher/signing route')) {
    if (($docs -replace '\s+', ' ') -notlike "*$phrase*") { throw "Missing policy-stop documentation: $phrase" }
}
Write-Host 'PASS: static collector policy guardrails and stop documentation.'
