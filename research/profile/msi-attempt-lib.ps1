# Durable preparation records, not authorization to execute or recreate an arm marker.
function Write-MsiNewRecord([string]$Path,$Value){
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 8))
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function New-MsiAttemptPlan([string]$StateDirectory,[string]$PackageDirectory,[string]$PriorEvidenceSha256){
 if($PriorEvidenceSha256 -cnotmatch '^[0-9a-f]{64}$'){throw 'A reviewed prior evidence hash is required'}
 $package=Assert-MsiPackage $PackageDirectory
 $attempts=Join-Path $StateDirectory 'Attempts';[void][IO.Directory]::CreateDirectory($attempts)
 # Until durable EFI STARTED/FINISHED receipts are implemented and qualified,
 # a prepared plan is the only supported state. No second plan bypasses it.
 if(@(Get-ChildItem -LiteralPath $attempts -Force).Count){throw 'An attempt already exists; pending/failed/ambiguous state cannot be rearmed'}
 $plan=[ordered]@{
  Schema='msi-attempt-plan-v1';AttemptId=[guid]::NewGuid().ToString('N');State='PreparedNotArmed'
  ProfileId=$package.ProfileId;PackageSha256=(Get-MsiPackageHash (Join-Path $PackageDirectory 'package.json'))
  EfiSha256=(Get-MsiPackageHash (Join-Path $PackageDirectory 'UNLOCK.EFI'))
  AssetManifestSha256=(Get-MsiPackageHash (Join-Path $PackageDirectory 'assets.json'))
  PriorEvidenceSha256=$PriorEvidenceSha256;CreatedUtc=[datetime]::UtcNow.ToString('o')
  AuthorizationToExecute=$false;RearmEnabled=$false;AutomaticRetry=$false
 }
 $path=Join-Path $attempts 'attempt-0001.json';Write-MsiNewRecord $path $plan
 $readback=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 if($readback.AttemptId -cne $plan.AttemptId -or $readback.PackageSha256 -cne $plan.PackageSha256 -or $readback.AuthorizationToExecute -ne $false){throw 'Attempt plan readback failed; preserve incomplete state'}
 return $path
}
