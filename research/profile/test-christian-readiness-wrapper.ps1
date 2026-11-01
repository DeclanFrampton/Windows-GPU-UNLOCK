$ErrorActionPreference='Stop'
$global:readinessPresent=$false
function Get-Command {param($Name,$ErrorAction)if($global:readinessPresent -and $Name -eq 'python'){return 'Invoke-FakeReadinessPython'};return $null}
function Invoke-FakeReadinessPython {
 if($args[0] -cne '-c' -or $args[1] -notlike '*find_spec*' -or $args[1] -match 'import torch'){throw 'Unexpected Python execution'}
 $global:LASTEXITCODE=0;'TORCH_PRESENT'
}
$fixture=Join-Path $PSScriptRoot ('build/readiness-test-'+[guid]::NewGuid().ToString('N'))
foreach($present in @($false,$true)){
 $global:readinessPresent=$present
 $out=& (Join-Path $PSScriptRoot 'test-christian-benchmark-readiness.ps1') -Results (Join-Path $fixture "$present") | ConvertFrom-Json
 if(!(Test-Path -LiteralPath $out.evidence_zip)){throw 'Missing ZIP'}
 $r=Get-ChildItem -LiteralPath (Join-Path $fixture "$present") -Recurse -Filter readiness.json | Get-Content -Raw | ConvertFrom-Json
 if($r.gpu_workload_run -or $r.software_installed -or $r.torch_imported -or $r.python_found -ne $present){throw 'Wrong readiness flags'}
 if($present -and $r.torch_package_present -ne $true){throw 'Python package discovery failed'}
}
Write-Host 'PASS missing-tool result and Python package discovery without torch import; ZIPs created. Tool discovery/execution mocked.'
