# Development build and host mocks only; never stages or boots the artifact.
param([string]$Clang='clang',[string]$LldLink='lld-link')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'build-shared-esp-unlock.ps1') -WindowsEspGuid 'c36c3e86-02aa-4f76-af1b-96e327f9d1c1' -AttemptSlot 9 -SecondSharedAttempt -Clang $Clang -LldLink $LldLink
& (Join-Path $PSScriptRoot 'test-shared-esp-unlock-gate.ps1') -SecondSharedAttempt -Clang $Clang -LldLink $LldLink
& (Join-Path $PSScriptRoot 'test-shared-esp-unlock-prepare.ps1') -SecondSharedAttempt -Clang $Clang -LldLink $LldLink
Write-Host 'SULK02 development build and 14 host cases complete. NOT STAGED. Do not boot: launcher and staging integration pending.'
