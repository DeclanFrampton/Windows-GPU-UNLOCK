# CPU-only wrapper/graph tests and optional real-core replay with private captures/assets.
param([string]$Clang='clang',[string]$LldLink='lld-link',[string]$Prom='',[string]$Capture='',[string]$Assets='',
 [string]$VcVars='C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvars64.bat')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));Push-Location $repo
try {
 $out='research/profile/build/msi-transaction-tests';[void][IO.Directory]::CreateDirectory((Join-Path $repo $out))
 $defs=@('-DGU_PROFILE_MSI_H510_3090','-DGU_MSI_TRANSACTION_DEVELOPMENT','-DGU_MSI_UNLOCK','-DGU_EXPERIMENTAL_3090','-DGU_ENTRY_LATCHED_SS1_FULL')
 $flags=@('-target','x86_64-pc-windows-msvc','-std=c11','-ffreestanding','-fno-builtin','-fno-stack-protector','-fshort-wchar','-Os','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-I','deps/edk2/MdePkg/Include','-I','deps/edk2/MdePkg/Include/X64')+$defs
 $objects=@{}
 foreach($file in @('internal-boot/unlock/runtime.c','internal-boot/unlock/format.c','internal-boot/unlock/checks.c','internal-boot/unlock/tests/test_msi_transaction.c','internal-boot/boot/test-msi-transaction-graph.c')){
  $name=[IO.Path]::GetFileNameWithoutExtension($file);$obj=Join-Path $out ($name+'.obj')
  & $Clang @flags -c $file -o $obj;if($LASTEXITCODE -ne 0){throw "Compile failed: $file"};$objects[$name]=$obj
 }
 foreach($test in @('test_msi_transaction','test-msi-transaction-graph')){
  $objs=@($objects[$test],$objects['runtime']);if($test -eq 'test_msi_transaction'){$objs+=@($objects['format'],$objects['checks'])}
  $exe=Join-Path $out ($test+'.exe');& $LldLink /nologo /nodefaultlib /subsystem:console /entry:main /machine:x64 "/out:$exe" @objs
  if($LASTEXITCODE -ne 0){throw "Link failed: $test"}; & (Join-Path $repo $exe);if($LASTEXITCODE -ne 0){throw "Scenario failed: $test/$LASTEXITCODE"}
 }
 'PASS 23 wrapper cases with repeat refusal and 17 graph ownership cases; GPU core/hash/callbacks mocked'
 if($Prom -or $Capture -or $Assets){
  if(!$Prom -or !$Capture -or !$Assets){throw 'Provide all of Prom, Capture and Assets for real-core replay'}
  $Prom=[IO.Path]::GetFullPath($Prom);$Capture=[IO.Path]::GetFullPath($Capture);$Assets=[IO.Path]::GetFullPath($Assets)
  if((Get-FileHash -LiteralPath $Prom).Hash.ToLowerInvariant() -ne 'de78e145e527059faec711a9a320b6dca6a88dc4de0fed882d1688ba2dd1aad1'){throw 'MSI PROM hash mismatch'}
  foreach($spec in (Get-Content internal-boot/unlock/assets.json -Raw | ConvertFrom-Json)){
   $file=Join-Path $Assets $spec.Name;if((Get-Item -LiteralPath $file).Length -ne $spec.Bytes -or (Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -ne $spec.Sha256){throw 'Private payload mismatch'}
  }
  $line=Get-Content -LiteralPath $Capture | Where-Object {$_ -like 'cfg dwords=*'} | Select-Object -First 1
  $cfg=@(($line -replace '^cfg dwords=','').Trim().Split(' ',[StringSplitOptions]::RemoveEmptyEntries));if($cfg.Count -ne 64){throw 'Expected captured 256-byte config'}
  # The live admission proved memory-only command2; generic graph was captured before teardown.
  $cfg[1]=('{0:x8}' -f (([Convert]::ToUInt32($cfg[1],16) -band 0xffff0000L) -bor 2))
  $config=Join-Path $repo "$out/captured-config.txt"
  @(for($i=0;$i -lt 64;$i+=4){'config[{0:x2}]={1}' -f ($i*4),($cfg[$i..($i+3)] -join ' ')}) | Set-Content -LiteralPath $config -Encoding ascii
  . ./research/profile/host.ps1;Import-GuHostCompiler $VcVars
  Push-Location internal-boot/unlock
  try {
   $hostFlags=@('-std=c11','-O1','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-Wno-unused-function','-D_CRT_SECURE_NO_WARNINGS','-D__KERNEL__','-DGU_UEFI_PORT','-Icompat','-I../../deps/edk2/MdePkg/Include','-I../../deps/edk2/MdePkg/Include/X64')+$defs
   $src=@('tests/test_efi_transaction.c','checks.c','port.c','compat.c','vendor/unlock_610.c','vendor/prep_610.c','vendor/layout_610.c','vendor/vbios_610.c','vendor/gfw_eval.c')
   $exe=Join-Path $repo "$out/real-core.exe";& $Clang @hostFlags @src -o $exe;if($LASTEXITCODE -ne 0){throw 'Real core compile failed'}
   & $exe ([IO.Path]::GetFullPath($Prom)) ([IO.Path]::GetFullPath($Assets)) $config *> (Join-Path $repo "$out/real-core.txt")
   if($LASTEXITCODE -ne 0){throw 'Real core replay failed; inspect real-core.txt'}
   Get-Content (Join-Path $repo "$out/real-core.txt") -Tail 1
  }finally{Pop-Location}
 }else{'Real-core replay skipped: private PROM, capture and assets were not supplied'}
}finally{Pop-Location}
