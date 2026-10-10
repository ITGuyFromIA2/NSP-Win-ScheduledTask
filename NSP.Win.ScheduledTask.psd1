@{
    RootModule = 'NSP.Win.ScheduledTask.psm1'
    ModuleVersion = '0.1.0'
    GUID = '641a2a46-caa9-4b8d-bd7d-57de66ecc21d'
    Author = 'Network Systems Plus'
    CompanyName = 'Network Systems Plus'
    Copyright = '(c) 2026 Network Systems Plus. All rights reserved.'
    Description = 'Scheduled tasks for unattended jobs: one definition to register a task (SYSTEM, gMSA, or user; time or event-log triggers) and to check an installed task for drift.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'New-NSPEventTaskTrigger'
        'New-NSPScheduledTaskDefinition'
        'Register-NSPScheduledTask'
        'Test-NSPScheduledTask'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('ScheduledTask', 'TaskScheduler', 'gMSA', 'Automation', 'Windows', 'NSP')
            ProjectUri = 'https://github.com/ITGuyFromIA2/NSP-Win-ScheduledTask'
            LicenseUri = 'https://github.com/ITGuyFromIA2/NSP-Win-ScheduledTask/blob/main/LICENSE'
            ReleaseNotes = '0.1.0: first release. Task definitions (PowerShell file/command or any program; SYSTEM, gMSA, or user), event-log triggers, register, drift check.'
        }
    }
}
