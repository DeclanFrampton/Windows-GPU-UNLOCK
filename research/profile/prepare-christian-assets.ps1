# Prepare payload files on Windows only. No GPU access, USB staging or reboot.
param([string]$Root='C:\GPU-Unlock',[string]$Assets)
$ErrorActionPreference='Stop'
$revision='4e7cef178a52465cfd0a20396839bf6203f096f7'
if(!$Assets){$Assets=Join-Path $Root 'Assets/ga102'}
$python=Get-Command python -ErrorAction Stop
$version=& $python.Source -c 'import sys; print(sys.version_info.major*100+sys.version_info.minor)'
if($LASTEXITCODE -ne 0 -or [int]$version -lt 312){throw 'Python 3.12+ required. Send this error; install nothing yet.'}
$work=Join-Path $Root ('Builds/assets-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
Invoke-WebRequest -UseBasicParsing ('https://github.com/DeclanFrampton/Windows-GPU-UNLOCK/archive/'+$revision+'.zip') -OutFile (Join-Path $work 'source.zip')
Expand-Archive -LiteralPath (Join-Path $work 'source.zip') -DestinationPath $work
$repo=Join-Path $work ('Windows-GPU-UNLOCK-'+$revision)
$generator=Join-Path $repo 'research/profile/prepare-evga3090-assets.py'
$runner=$python.Source
if([int]$version -lt 314 -and !(Test-Path -LiteralPath $Assets)){
 $environment=Join-Path $work 'python-env'
 & $python.Source -m venv $environment
 if($LASTEXITCODE -ne 0){throw 'Private Python environment could not be created. Send the error.'}
 $runner=Join-Path $environment 'Scripts/python.exe'
 $requirements=Join-Path $work 'requirements.txt'
 'zstandard==0.25.0 --hash=sha256:ffef5a74088f1e09947aecf91011136665152e0b4b359c42be3373897fb39b01 --hash=sha256:1f830a0dac88719af0ae43b8b2d6aef487d437036468ef3c2ea59c51f9d55fd5' | Set-Content -LiteralPath $requirements -Encoding ascii
 & $runner -m pip --isolated --disable-pip-version-check install --index-url https://pypi.org/simple --only-binary=:all: --no-deps --require-hashes -r $requirements
 if($LASTEXITCODE -ne 0){throw 'Pinned decompressor installation failed. Send the error; no global packages were changed.'}
}
if(Test-Path -LiteralPath $Assets){
 & $runner -I $generator --verify-only --output $Assets
}else{
 if(!(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git not found. Send this error.'}
 & $runner -I $generator --source (Join-Path $work 'payload-source') --output $Assets
}
if($LASTEXITCODE -ne 0){throw 'Payload preparation/verification failed. Preserve files and send this error; do not boot USB.'}
$specs=Get-Content -LiteralPath (Join-Path $repo 'internal-boot/unlock/assets.json') -Raw | ConvertFrom-Json
$verified=@(foreach($spec in $specs){
 $file=Join-Path $Assets $spec.Name
 $item=Get-Item -LiteralPath $file
 if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Payload links refused'}
 $hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
 if($item.Length -ne $spec.Bytes -or $hash -ne $spec.Sha256){throw ('Payload mismatch: '+$spec.Name)}
 [ordered]@{name=$spec.Name;bytes=$item.Length;sha256=$hash}
})
foreach($name in @('NVIDIA-LICENSE','NOTICE.md')){if(!(Test-Path -LiteralPath (Join-Path $Assets $name) -PathType Leaf)){throw ('Required notice missing: '+$name)}}
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$out=Join-Path $results ('christian-assets-result-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($out)
[ordered]@{test='christian-ga102-payload-preparation-v1';source_revision=$revision;assets_directory=$Assets;assets=$verified;gpu_accessed=$false;efi_staged=$false;unlock_attempted=$false;automatic_reboot=$false} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Output ('Ready. No reboot. Attach this report ZIP only: '+$out+'.zip')
Write-Output 'Keep payloads, NVIDIA-LICENSE and NOTICE.md locally. Do not upload firmware. USB was not changed.'
