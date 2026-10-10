function Register-NSPScheduledTask {
    <#
    .SYNOPSIS
        Creates or replaces the scheduled task a New-NSPScheduledTaskDefinition describes.
    .DESCRIPTION
        Builds the action, principal, and settings from the definition and registers the task
        (replacing one of the same name and path). Needs an elevated session. A gMSA must already
        be installed on this computer (Install-ADServiceAccount) and allowed to log on as a batch
        job, or the task will register but fail to start.
    .EXAMPLE
        New-NSPScheduledTaskDefinition -TaskName 'Nightly transfer' -PowerShellFile 'C:\Jobs\Send.ps1' -RunAs SYSTEM -Trigger (New-ScheduledTaskTrigger -Daily -At '22:00') | Register-NSPScheduledTask
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][PSTypeName('NSP.Win.ScheduledTask.Definition')]$Definition
    )

    process {
        $d = $Definition
        $actionArgs = @{ Execute = $d.Execute }
        if ($d.Argument) { $actionArgs.Argument = $d.Argument }
        if ($d.WorkingDirectory) { $actionArgs.WorkingDirectory = $d.WorkingDirectory }
        $settingsArgs = @{ ExecutionTimeLimit = $d.ExecutionTimeLimit; MultipleInstances = $d.MultipleInstances }
        if ($d.WakeToRun) { $settingsArgs.WakeToRun = $true }
        if ($d.StartWhenAvailable) { $settingsArgs.StartWhenAvailable = $true }

        $register = @{
            TaskName = $d.TaskName; TaskPath = $d.TaskPath
            Action = (New-ScheduledTaskAction @actionArgs)
            Trigger = $d.Trigger
            Settings = (New-ScheduledTaskSettingsSet @settingsArgs)
            Force = $true; ErrorAction = 'Stop'
        }
        if ($d.Description) { $register.Description = $d.Description }
        switch ($d.AccountKind) {
            'System' { $register.Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel $d.RunLevel }
            'ManagedServiceAccount' { $register.Principal = New-ScheduledTaskPrincipal -UserId $d.RunAs -LogonType Password -RunLevel $d.RunLevel }
            'User' {
                $register.User = $d.Credential.UserName
                $register.Password = $d.Credential.GetNetworkCredential().Password
                $register.RunLevel = $d.RunLevel
            }
        }

        if (-not $PSCmdlet.ShouldProcess("$($d.TaskPath)$($d.TaskName)", "Register scheduled task (runs as $($d.RunAs))")) { return }
        Register-ScheduledTask @register
    }
}
