$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'msi-rearm-policy.ps1')
$id='0123456789abcdef0123456789abcdef'
$efi=[pscustomobject]@{attempt_id=$id;started_receipt_matches=$true;finished_receipt_matches=$true;matching_log_count=1;efi_receipt_and_log_complete=$true;automatic_windows_return='Yes'}
$display=[pscustomobject]@{attempt_id=$id;picture_returned='Login';recovery_action='Nothing'}
$r=Get-MsiRearmReview $efi $display;if(!$r.EligibleForRearmQualification -or $r.ExecutionAuthorized){throw 'Clean review does not remain review-only'}
foreach($case in @('Manual','Later','Unknown','StillNone')){
 $display.picture_returned=$case;$display.recovery_action='PowerOff';$r=Get-MsiRearmReview $efi $display
 if($r.EligibleForRearmQualification -or $r.ExecutionAuthorized){throw 'Display failure allowed rearm review'}
}
$display.picture_returned='Login';$display.recovery_action='Nothing';$display.attempt_id='ffffffffffffffffffffffffffffffff'
if((Get-MsiRearmReview $efi $display).EligibleForRearmQualification){throw 'Mismatched attempt accepted'}
$display.attempt_id=$id;$efi.finished_receipt_matches=$false
if((Get-MsiRearmReview $efi $display).EligibleForRearmQualification){throw 'Partial EFI accepted'}
$blocked=$false;try{& (Join-Path $PSScriptRoot 'run-christian-rearm.ps1') -Mode Stage -AcceptRearmRisk}catch{if($_.Exception.Message -like 'MSI staging is on display-recovery hold*'){$blocked=$true}else{throw}}
if(!$blocked){throw 'Staging was not held before storage access'}
'PASS clean review remains unauthorized; manual/late/unknown/no-display, wrong ID, incomplete EFI and staging hold'
