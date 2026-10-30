# Preview by default. Only a maintainer with triage rights can use -Apply.
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$repository = 'windows-GPU-UNLOCK/Windows-GPU-UNLOCK'
$plan = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'issue-label-plan.json') -Raw | ConvertFrom-Json
if ($plan.repository -cne $repository) { throw 'Unexpected target repository' }
$allowed = @('documentation','enhancement','question','bug')
$seen = @{}
foreach ($row in $plan.issues) {
    if ($row.number -isnot [int] -and $row.number -isnot [long]) { throw 'Invalid issue number' }
    if ($row.number -lt 1 -or $seen.ContainsKey([string]$row.number)) { throw 'Duplicate or invalid issue number' }
    $seen[[string]$row.number] = $true
    if ($row.body_sha256 -cnotmatch '^[0-9a-f]{64}$' -or !$row.title) { throw 'Invalid snapshot identity' }
    if (@($row.add_labels).Count -eq 0) { throw 'Empty label proposal' }
    foreach ($label in $row.add_labels) {
        if ($allowed -cnotcontains $label) { throw 'Unexpected label' }
    }
    Write-Output ("#{0}: +{1}" -f $row.number, ($row.add_labels -join ', +'))
}
if (!$Apply) {
    Write-Output 'Preview only. No GitHub changes. Review README.md and the JSON plan before using -Apply.'
    return
}
function Invoke-GhJson([string[]]$Arguments) {
    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'GitHub read failed; no further changes attempted' }
    return (($output -join "`n") | ConvertFrom-Json)
}
$repo = Invoke-GhJson @('api', "repos/$repository")
if ($repo.id -ne 1426503435) { throw 'Repository identity changed; nothing applied' }
if (!$repo.permissions.triage -and !$repo.permissions.push -and !$repo.permissions.maintain -and !$repo.permissions.admin) {
    throw 'This account lacks repository triage permission. Nothing applied.'
}
$labels = Invoke-GhJson @('api', "repos/$repository/labels?per_page=100")
foreach ($label in $allowed) {
    if (@($labels | Where-Object name -CEQ $label).Count -ne 1) { throw 'An expected repository label is missing' }
}
$current = Invoke-GhJson @('issue','list','--repo',$repository,'--state','all','--limit','1000','--json','number,title,body,labels')
$pending = @()
$sha = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($row in $plan.issues) {
        $issue = @($current | Where-Object number -EQ $row.number)
        if ($issue.Count -ne 1) { throw 'Issue snapshot no longer matches; refresh the plan before applying' }
        $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$issue[0].body)))).Replace('-','').ToLowerInvariant()
        if ($hash -cne $row.body_sha256 -or $issue[0].title -cne $row.title) {
            throw ("Issue #{0} changed; refresh the plan before applying any labels" -f $row.number)
        }
        foreach ($label in $row.add_labels) {
            if (@($issue[0].labels | Where-Object name -CEQ $label).Count -eq 0) {
                $pending += @{Number=$row.number; Label=$label}
            }
        }
    }
} finally { $sha.Dispose() }
foreach ($change in $pending) {
    if ($PSCmdlet.ShouldProcess("$repository #$($change.Number)", "Add label $($change.Label)")) {
        & gh issue edit ([string]$change.Number) --repo $repository --add-label $change.Label
        if ($LASTEXITCODE -ne 0) { throw 'Label update failed. Earlier successful additions remain; rerun after resolving access.' }
    }
}
Write-Output 'Finished. Existing labels were preserved; no issues were closed or edited.'
