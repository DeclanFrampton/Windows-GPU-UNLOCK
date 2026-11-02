# Review policy only; a positive review result never authorizes hardware execution.
function Get-MsiRearmReview($Efi,$Display){
 $reasons=@()
 if($Efi.attempt_id -cnotmatch '^[0-9a-f]{32}$' -or $Display.attempt_id -cne $Efi.attempt_id){$reasons+='Attempt identity mismatch'}
 if(!$Efi.started_receipt_matches -or !$Efi.finished_receipt_matches -or $Efi.matching_log_count -ne 1 -or !($Efi.efi_receipt_and_log_complete -eq $true -or $Efi.complete_success -eq $true)){$reasons+='EFI receipt/log completion not established'}
 if($Efi.automatic_windows_return -ine 'Yes'){$reasons+='Automatic Windows return not established'}
 if($Display.picture_returned -ine 'Login' -or $Display.recovery_action -ine 'Nothing'){$reasons+='Display return requires review; manual recovery or late/unknown picture is not qualified'}
 [pscustomobject]@{Schema='msi-rearm-review-v1';AttemptId=$Efi.attempt_id;EligibleForRearmQualification=($reasons.Count -eq 0);ExecutionAuthorized=$false;AutomaticRetry=$false;Reasons=$reasons}
}
