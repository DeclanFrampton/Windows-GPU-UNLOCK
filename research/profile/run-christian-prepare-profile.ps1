# Windows-only installer preparation. No USB/ESP mutation, arm marker, GPU workload or reboot.
param([string]$Root='C:\GPU-Unlock')
$ErrorActionPreference='Stop'
$revision='cef769071af44c17049d3df9520d260f1850dbd1'
$results=Join-Path $Root 'Results';[void][IO.Directory]::CreateDirectory($results)
$out=Join-Path $results ('christian-profile-preparation-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($out)
$errorText=$null;$prepared=$false
try {
 $clang=Get-Command clang -ErrorAction SilentlyContinue;$lld=Get-Command lld-link -ErrorAction SilentlyContinue
 if(!$clang){$clang=Get-Command 'C:\Program Files\LLVM\bin\clang.exe' -ErrorAction Stop}
 if(!$lld){$lld=Get-Command 'C:\Program Files\LLVM\bin\lld-link.exe' -ErrorAction Stop}
 $py=Get-Command python -ErrorAction Stop
 $work=Join-Path $Root ('Builds/msi-package-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($work)
 $archive=Join-Path $work 'source.zip'
 Invoke-WebRequest -UseBasicParsing ('https://github.com/DeclanFrampton/Windows-GPU-UNLOCK/archive/'+$revision+'.zip') -OutFile $archive
 Expand-Archive -LiteralPath $archive -DestinationPath $work
 $repo=Join-Path $work ('Windows-GPU-UNLOCK-'+$revision)
 $package=Join-Path $work 'Package'
 # Git archives lack .git; supply the known pinned provenance through the builder.
 & (Join-Path $repo 'research/profile/build-msi-profile.ps1') -OutputDirectory $package -SourceRevision $revision -Clang $clang.Source -LldLink $lld.Source -Python $py.Source *> (Join-Path $out 'build.txt')
 $state=Join-Path $Root 'MSI-Profile-Preparation'
 & (Join-Path $repo 'research/profile/prepare-msi-install.ps1') -PackageDirectory $package -StateDirectory $state *> (Join-Path $out 'prepare.txt')
 foreach($name in @('package.json','profile.json','source-manifest.json','pe-verification.json')){Copy-Item -LiteralPath (Join-Path $package $name) -Destination $out}
 Copy-Item -LiteralPath (Join-Path $state 'installation-plan.json') -Destination $out
 $prepared=$true
}catch{$errorText=$_.Exception.Message}
[ordered]@{prepared=$prepared;error=$errorText;source_revision=$revision;installed=$false;armed=$false;gpu_workload_run=$false;usb_written=$false;firmware_written=$false;automatic_reboot=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding utf8
Compress-Archive -LiteralPath $out -DestinationPath ($out+'.zip')
Write-Output ('Attach this ZIP: '+$out+'.zip')
if($errorText){Write-Output ('Preparation stopped: '+$errorText+'; preserve existing state')}
