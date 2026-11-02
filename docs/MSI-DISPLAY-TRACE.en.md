# MSI display-return diagnosis: capture before recovery

The receipt-enabled unlock completed in EFI, but DisplayPort needed manual
power-off recovery. Existing reports describe the recovery boot; they cannot
show the failed session's graphics-driver initialization. A normal Windows
control boot trace is the next diagnostic step. It does not authorize an EFI
retry, rearm or change the GPU reset sequence.

## Mechanism

christian-boot-trace.ps1 configures a uniquely named WPR boot autologger and one
SYSTEM startup task. The custom profile records only the DxgKrnl provider using
the keyword mask from the installed built-in GPU.Light profile, without stack
or system-collector profiling. Main circular buffers total32 MiB. The task runs
30seconds after startup, saves the trace and removes its owned task. Successful
WPR stopboot also removes its autologger configuration. If stopping fails, the
worker attempts cancellation of only its named instance. No automatic retry.

The worker and dependencies live in an Administrators/SYSTEM-only ProgramData
folder, with owner and file ACLs set before task registration. State binds the
worker/dependency hashes and exact task action. Changed task/worker/dependency,
same-boot invocation, existing state or a claimed finish refuses execution.
The worker's result records its actual Windows boot UTC, so recovery-boot
recordings must never be mistaken for the preceding failed boot.

WPR boot recording is documented by Microsoft:
https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpr-command-line-options#boottrace
The installed wpr -help boottrace and -profiledetails validated the command
syntax and custom profile on the development host. This is not live startup
validation on Christian's computer.

## Contributor control test

Run the pinned single script as Administrator with -AcceptTraceSetup. This
accepts temporary boot-tracing registry configuration and a startup task, some
profiling/startup overhead and local diagnostic metadata. Keep USB disconnected.
Use normal Windows Restart manually; the script never reboots. After Windows
returns wait90seconds and run the same script -Mode Collect as Administrator.
Return the christian-boot-trace summary ZIP and whether the picture returned
normally. The raw ETL stays local because it can contain process/image metadata;
no raw trace is included in the summary ZIP or automatically uploaded.

If the trace did not finish, run the same script -Mode Cancel as Administrator,
then collect the report. Cancellation touches only the owned WPR instance and
unchanged owned task. Preserve state after a failure; do not retry setup, delete
markers or boot the consumed unlock. If Windows itself fails during this normal
control boot, report it; no recovery guarantee or EFI retry is inferred.

## Verification and remaining boundary

WindowsPowerShell5.1 tests exercised eight worker success/failure/refusal cases,
repeat refusal, isolated native arguments, protected preparation/task settings
and cleanup after a failed WPR setup using mocked OS mutations. The installed
WPR parser accepted the actual custom profile and reported256 KiB x128 buffers,
DxgKrnl0x277, no system collector. Non-administrator invocation produced a ZIP
without configuration. The development session is not elevated, so actual task
registration, boot autologger setup and post-reboot automatic saving remain
unverified until this control test. No local reboot or trace was enabled.
