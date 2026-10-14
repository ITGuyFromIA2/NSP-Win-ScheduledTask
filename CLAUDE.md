# CLAUDE.md

## What this is

`NSP.Win.ScheduledTask`: scheduled-task definitions, registration, and drift checks. Part of the
`NSP.Win.*` family. First consumer: the setup of `NSP-PoSHToolkits\NSP-FileTransfer` jobs.
`NSP-M365-ConditionalAccess` has its own private task registration that could move here.

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

## Publishing (not adopted yet - do this on next use)

This repo isn't on the shared NSP release routine yet. Before its next release, adopt it the way
the published toolkit repos have (NSP-Console, NSP-Toolkit, NSP-ActiveDirectory, NSP-Bootstrap):

- Add `tools\Publish-ToGallery.ps1`: the same thin wrapper those repos carry, which imports
  NSP.RepoTools and runs `Publish-NSPModule` on this repo. Copy it as-is; all the logic stays in
  NSP.RepoTools.
- Dry run first: `.\tools\Publish-ToGallery.ps1 -WhatIf` runs every check (manifest, changelog,
  clean tree, Gallery version, client references across history, `tools\Test-Repo.ps1`, staged
  5.1 import) and publishes nothing.
- At release, change the CHANGELOG heading from `## <version> (unreleased)` to `## <version>`;
  the routine refuses an unreleased heading.
- Needs a GitHub remote first if the repo has none (the manifest's ProjectUri should point at it).