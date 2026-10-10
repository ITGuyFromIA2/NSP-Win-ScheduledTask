# NSP.Win.ScheduledTask

Scheduled tasks for unattended jobs, described once and used twice: to register the task, and
later to check the installed task hasn't drifted. Windows PowerShell **5.1** compatible (and 7+);
imports on a bare host. Part of the `NSP.Win.*` family.

| Function | Purpose |
|---|---|
| `New-NSPScheduledTaskDefinition` | The task as data: a PowerShell script or command (run by Windows PowerShell 5.1 with `-NoProfile -NonInteractive -ExecutionPolicy Bypass`) or any program; SYSTEM, a gMSA (`DOMAIN\name$`), or a user with `-Credential`; triggers; time limit, overlap rule, wake-to-run. |
| `New-NSPEventTaskTrigger` | An "on an event" trigger from a log + event ID (+ provider), or a full event query - e.g. Sysmon event 11 to run a job when a file lands. |
| `Register-NSPScheduledTask` | Create or replace the task from a definition (elevated). |
| `Test-NSPScheduledTask` | Compare the installed task with a definition: `Exists`, `InSync`, and one line per difference. |

```powershell
Import-Module NSP.Win.ScheduledTask
$nightly = New-NSPScheduledTaskDefinition -TaskName 'Nightly transfer' -TaskPath '\NSP\' `
    -PowerShellCommand "Import-NSPFileTransferProfile 'C:\Jobs\Example.Profile.psd1' | Invoke-NSPFileTransfer" `
    -RunAs 'CONTOSO\svc_transfer$' -Trigger (New-ScheduledTaskTrigger -Daily -At '22:00') -WakeToRun

$nightly | Test-NSPScheduledTask              # what would change
$nightly | Register-NSPScheduledTask          # make it so
```

## Accounts

- **gMSA** (`DOMAIN\name$`): registered with the Password logon type, which tells Task Scheduler to
  fetch the account's managed password itself. The gMSA must be installed on the computer
  (`Install-ADServiceAccount`) and allowed to log on as a batch job.
- **SYSTEM**: no setup, but the job then runs with the machine's full rights.
- **A user**: `-Credential` for that user; Task Scheduler stores the password.

## Tests

```powershell
.\tools\Test-Repo.ps1
```

Pester 5+. Nothing is registered: Register-ScheduledTask and Get-ScheduledTask are mocked, and the
task objects are real ones built offline by the ScheduledTasks cmdlets.
