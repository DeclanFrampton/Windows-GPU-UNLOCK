# Existing-file observations only. No profile generation, GPU access, staging or boot.
[CmdletBinding()]
param([string]$CaptureFolder,[string]$Python='python')
$ErrorActionPreference='Stop'
if(!$CaptureFolder){$CaptureFolder=Read-Host 'Existing folder containing DIAGnn.TXT and IMGnn.BIN'}
$pythonCommand=Get-Command $Python -ErrorAction Stop
if($pythonCommand.Source -match 'WindowsApps'){throw 'Python resolves to an app installer stub; stop without installing or changing anything.'}
$lines=& $pythonCommand.Source -I -B (Join-Path $PSScriptRoot 'review-driver-capture.py') $CaptureFolder
if($LASTEXITCODE -ne 0){throw 'Offline review failed. Preserve original files; no hardware retry.'}
$result=($lines -join [Environment]::NewLine)|ConvertFrom-Json
if($result.test -cne 'captured-driver-review-v1' -or $result.write_eligible -or $result.profile_generated){throw 'Unexpected review scope.'}
$docs=[Environment]::GetFolderPath('MyDocuments');if(!$docs){throw 'Documents folder unavailable.'}
$folder=Join-Path $docs ('GPU-Unlock-Driver-Review-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $folder|Out-Null
$path=Join-Path $folder 'driver-review.json'
$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding utf8
Write-Host ('Return only reviewed '+$path+'. Keep captures local; no settings changes or boot.')
