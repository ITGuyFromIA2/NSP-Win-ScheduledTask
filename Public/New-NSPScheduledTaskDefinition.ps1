function New-NSPScheduledTaskDefinition {
    <#
    .SYNOPSIS
        Describes a scheduled task once - action, account, triggers, settings - for Register-NSPScheduledTask and Test-NSPScheduledTask.
    .DESCRIPTION
        Nothing is registered here. The same definition installs the task and later checks an
        installed task against it, so setup and drift checks can't disagree.

        Action: -PowerShellFile or -PowerShellCommand runs Windows PowerShell 5.1
        (%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe) with -NoProfile
        -NonInteractive -ExecutionPolicy Bypass; -Execute / -Argument runs anything else.

        Account (-RunAs): 'SYSTEM'; a group managed service account ('DOMAIN\name$' - the trailing $
        marks it, and Windows fetches its password itself); or another account with -Credential.
        Tasks run with highest privileges unless -LimitedRunLevel.
    .EXAMPLE
        New-NSPScheduledTaskDefinition -TaskName 'Nightly transfer' -PowerShellFile 'C:\Jobs\Send.ps1' -RunAs 'CONTOSO\svc_transfer$' -Trigger (New-ScheduledTaskTrigger -Daily -At '22:00')
    .EXAMPLE
        $drop = New-NSPEventTaskTrigger -LogName 'Microsoft-Windows-Sysmon/Operational' -EventId 11
        New-NSPScheduledTaskDefinition -TaskName 'Encrypt on drop' -PowerShellCommand "Import-NSPFileTransferProfile 'C:\Jobs\p.psd1' | Invoke-NSPFileTransferEncryption" -RunAs SYSTEM -Trigger $drop
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an object in memory; nothing on the system changes.')]
    [CmdletBinding(DefaultParameterSetName = 'File')]
    [OutputType('NSP.Win.ScheduledTask.Definition')]
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [string]$TaskPath = '\',
        [string]$Description,
        [Parameter(Mandatory, ParameterSetName = 'File')][string]$PowerShellFile,
        [Parameter(Mandatory, ParameterSetName = 'Command')][string]$PowerShellCommand,
        [Parameter(Mandatory, ParameterSetName = 'Execute')][string]$Execute,
        [Parameter(ParameterSetName = 'Execute')][string]$Argument,
        [string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$RunAs,
        [pscredential]$Credential,
        [switch]$LimitedRunLevel,
        [Parameter(Mandatory)][ciminstance[]]$Trigger,
        [timespan]$ExecutionTimeLimit = (New-TimeSpan -Hours 1),
        [ValidateSet('IgnoreNew', 'Parallel', 'Queue', 'StopExisting')][string]$MultipleInstances = 'IgnoreNew',
        [switch]$WakeToRun,
        [switch]$StartWhenAvailable
    )

    if (-not $TaskPath.EndsWith('\')) { $TaskPath += '\' }
    if (-not $TaskPath.StartsWith('\')) { $TaskPath = "\$TaskPath" }

    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $common = '-NoProfile -NonInteractive -ExecutionPolicy Bypass'
    switch ($PSCmdlet.ParameterSetName) {
        'File' { $exe = $powershell; $arguments = "$common -File `"$PowerShellFile`"" }
        'Command' { $exe = $powershell; $arguments = "$common -Command `"$($PowerShellCommand -replace '"', '\"')`"" }
        'Execute' { $exe = $Execute; $arguments = $Argument }
    }

    $kind = if ($RunAs -in 'SYSTEM', 'NT AUTHORITY\SYSTEM') { 'System' } elseif ($RunAs.EndsWith('$')) { 'ManagedServiceAccount' } else { 'User' }
    if ($kind -eq 'User' -and -not $Credential) { throw "Running as '$RunAs' needs -Credential (or use SYSTEM, or a gMSA ending in `$)." }
    if ($Credential -and $Credential.UserName -ne $RunAs) { throw "-Credential is for '$($Credential.UserName)', not -RunAs '$RunAs'." }

    [pscustomobject]@{
        PSTypeName         = 'NSP.Win.ScheduledTask.Definition'
        TaskName           = $TaskName
        TaskPath           = $TaskPath
        Description        = $Description
        Execute            = $exe
        Argument           = $arguments
        WorkingDirectory   = $WorkingDirectory
        RunAs              = if ($kind -eq 'System') { 'SYSTEM' } else { $RunAs }
        AccountKind        = $kind
        Credential         = $Credential
        RunLevel           = if ($LimitedRunLevel) { 'Limited' } else { 'Highest' }
        Trigger            = $Trigger
        ExecutionTimeLimit = $ExecutionTimeLimit
        MultipleInstances  = $MultipleInstances
        WakeToRun          = [bool]$WakeToRun
        StartWhenAvailable = [bool]$StartWhenAvailable
    }
}
