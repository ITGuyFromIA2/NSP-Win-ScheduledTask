# CLAUDE.md

## What this is

`NSP.Win.ScheduledTask`: scheduled-task definitions, registration, and drift checks. Part of the
`NSP.Win.*` family. First consumer: the setup of `NSP-PoSHToolkits\NSP-FileTransfer` jobs.
`NSP-ConditionalAccess` has its own private task registration that could move here.

## Hard rules

- Windows PowerShell 5.1 is the floor; imports on a bare host (no RequiredModules).
- One definition object feeds both Register and Test - add a setting to both or neither.
- Test-NSPScheduledTask is read-only. Register-NSPScheduledTask is the only function that
  changes Task Scheduler, behind ShouldProcess.
- Tests never register a task: mock Register-ScheduledTask / Get-ScheduledTask.
- One function per file. `FunctionsToExport` matches `Public\`. Exported functions need
  `.SYNOPSIS` and `.EXAMPLE`. CRLF, no BOM, ASCII only. Small (patch-level) version bumps.

## Testing

Pester 5+. Run `.\tools\Test-Repo.ps1`, and Pester under `powershell.exe` (5.1) too.
