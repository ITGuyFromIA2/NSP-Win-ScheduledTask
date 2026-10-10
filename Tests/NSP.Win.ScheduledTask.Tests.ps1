<#
    Pester 5. Nothing is registered: Register-ScheduledTask and Get-ScheduledTask are mocked. The
    action, principal, settings, and trigger objects are real ones built offline by the
    ScheduledTasks cmdlets, so the comparisons run against the shapes Windows actually returns.
#>

BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'NSP.Win.ScheduledTask.psd1') -Force -ErrorAction Stop
    # An "installed" task built the way Task Scheduler reports one.
    function Get-FakeInstalledTask {
        param($Definition, [string]$UserId, [string]$Arguments, [ciminstance[]]$Triggers, [string]$Limit = 'PT1H')
        $actionArgs = @{ Execute = $Definition.Execute }
        $arg = if ($PSBoundParameters.ContainsKey('Arguments')) { $Arguments } else { $Definition.Argument }
        if ($arg) { $actionArgs.Argument = $arg }
        $action = New-ScheduledTaskAction @actionArgs
        $user = if ($UserId) { $UserId } elseif ($Definition.AccountKind -eq 'System') { 'SYSTEM' } else { ($Definition.RunAs -split '\\')[-1] }
        $logon = if ($Definition.AccountKind -eq 'System') { 'ServiceAccount' } else { 'Password' }
        [pscustomobject]@{
            TaskName = $Definition.TaskName; Description = $Definition.Description
            Actions = @($action)
            Principal = (New-ScheduledTaskPrincipal -UserId $user -LogonType $logon -RunLevel Highest)
            Settings = (New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([Xml.XmlConvert]::ToTimeSpan($Limit)) -MultipleInstances IgnoreNew)
            Triggers = if ($Triggers) { $Triggers } else { $Definition.Trigger }
        }
    }
}

Describe 'New-NSPEventTaskTrigger' {
    It 'builds an event trigger with an XPath query for the log, provider, and IDs' {
        $t = New-NSPEventTaskTrigger -LogName 'Microsoft-Windows-Sysmon/Operational' -EventId 11 -Provider 'Microsoft-Windows-Sysmon'
        $t.CimClass.CimClassName | Should -Be 'MSFT_TaskEventTrigger'
        $t.Enabled | Should -BeTrue
        $t.Subscription | Should -Be "<QueryList><Query Id=`"0`" Path=`"Microsoft-Windows-Sysmon/Operational`"><Select Path=`"Microsoft-Windows-Sysmon/Operational`">*[System[Provider[@Name='Microsoft-Windows-Sysmon'] and (EventID=11)]]</Select></Query></QueryList>"
    }
    It 'ORs several event IDs and rejects a malformed subscription' {
        (New-NSPEventTaskTrigger -LogName 'Application' -EventId 1000, 1001).Subscription | Should -BeLike '*EventID=1000 or EventID=1001*'
        { New-NSPEventTaskTrigger -Subscription '<QueryList>' } | Should -Throw '*not valid XML*'
    }
}

Describe 'New-NSPScheduledTaskDefinition' {
    BeforeAll { $script:daily = New-ScheduledTaskTrigger -Daily -At '22:00' }

    It 'wraps a script in Windows PowerShell with the unattended switches' {
        $d = New-NSPScheduledTaskDefinition -TaskName 'Send' -PowerShellFile 'C:\Jobs\Send.ps1' -RunAs SYSTEM -Trigger $script:daily
        $d.Execute | Should -Be (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
        $d.Argument | Should -Be '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Jobs\Send.ps1"'
        $d.AccountKind | Should -Be 'System'
        $d.RunLevel | Should -Be 'Highest'
        $d.TaskPath | Should -Be '\'
    }
    It 'escapes double quotes in a -PowerShellCommand' {
        $d = New-NSPScheduledTaskDefinition -TaskName 'Cmd' -PowerShellCommand 'Write-Output "hi"' -RunAs SYSTEM -Trigger $script:daily
        $d.Argument | Should -Be '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Write-Output \"hi\""'
    }
    It 'treats an account ending in $ as a gMSA and needs a credential for anything else' {
        (New-NSPScheduledTaskDefinition -TaskName 'G' -Execute 'x.exe' -RunAs 'CONTOSO\svc_job$' -Trigger $script:daily).AccountKind | Should -Be 'ManagedServiceAccount'
        { New-NSPScheduledTaskDefinition -TaskName 'U' -Execute 'x.exe' -RunAs 'CONTOSO\jdoe' -Trigger $script:daily } | Should -Throw '*needs -Credential*'
    }
    It 'normalizes the task folder' {
        (New-NSPScheduledTaskDefinition -TaskName 'P' -TaskPath 'NSP' -Execute 'x.exe' -RunAs SYSTEM -Trigger $script:daily).TaskPath | Should -Be '\NSP\'
    }
}

Describe 'Register-NSPScheduledTask' {
    It 'registers a gMSA task with a Password-logon principal at the highest run level' {
        Mock -ModuleName NSP.Win.ScheduledTask Register-ScheduledTask { 'registered' }
        $d = New-NSPScheduledTaskDefinition -TaskName 'Send' -Description 'Nightly' -PowerShellFile 'C:\Jobs\Send.ps1' -RunAs 'CONTOSO\svc_job$' -Trigger (New-ScheduledTaskTrigger -Daily -At '22:00') -WakeToRun
        $d | Register-NSPScheduledTask -Confirm:$false | Should -Be 'registered'
        Should -Invoke -ModuleName NSP.Win.ScheduledTask Register-ScheduledTask -Times 1 -ParameterFilter {
            $TaskName -eq 'Send' -and $Force -and $Description -eq 'Nightly' -and
            $Principal.UserId -eq 'CONTOSO\svc_job$' -and "$($Principal.LogonType)" -eq 'Password' -and "$($Principal.RunLevel)" -eq 'Highest' -and
            $Action[0].Arguments -like '*-File "C:\Jobs\Send.ps1"' -and $Settings.WakeToRun -and $Settings.ExecutionTimeLimit -eq 'PT1H'
        }
    }
    It 'registers nothing with -WhatIf' {
        Mock -ModuleName NSP.Win.ScheduledTask Register-ScheduledTask { throw 'must not register' }
        New-NSPScheduledTaskDefinition -TaskName 'W' -Execute 'x.exe' -RunAs SYSTEM -Trigger (New-ScheduledTaskTrigger -Daily -At '01:00') | Register-NSPScheduledTask -WhatIf
        Should -Invoke -ModuleName NSP.Win.ScheduledTask Register-ScheduledTask -Times 0
    }
}

Describe 'Test-NSPScheduledTask' {
    BeforeAll {
        $script:drop = New-NSPEventTaskTrigger -LogName 'Microsoft-Windows-Sysmon/Operational' -EventId 11
        $script:def = New-NSPScheduledTaskDefinition -TaskName 'Encrypt' -Description 'On drop' -PowerShellCommand 'Invoke-Job' -RunAs 'CONTOSO\svc_job$' -Trigger $script:drop
    }

    It 'is in sync when the installed task matches (gMSA stored without its domain)' {
        Mock -ModuleName NSP.Win.ScheduledTask Get-ScheduledTask { Get-FakeInstalledTask -Definition $script:def }
        $r = $script:def | Test-NSPScheduledTask
        $r.Exists | Should -BeTrue
        $r.Differences | Should -BeNullOrEmpty
        $r.InSync | Should -BeTrue
    }
    It 'lists each difference' {
        $otherQuery = New-NSPEventTaskTrigger -LogName 'Application' -EventId 1
        Mock -ModuleName NSP.Win.ScheduledTask Get-ScheduledTask { Get-FakeInstalledTask -Definition $script:def -UserId 'old_svc$' -Arguments '-File C:\old.ps1' -Triggers $otherQuery -Limit 'PT2H' }
        $r = $script:def | Test-NSPScheduledTask
        $r.InSync | Should -BeFalse
        ($r.Differences -join "`n") | Should -BeLike '*Arguments*'
        ($r.Differences -join "`n") | Should -BeLike "*Account: expected 'svc_job$', found 'old_svc$'*"
        ($r.Differences -join "`n") | Should -BeLike '*Trigger 1 event query*'
        ($r.Differences -join "`n") | Should -BeLike "*Time limit: expected 'PT1H', found 'PT2H'*"
    }
    It 'compares a daily trigger by time of day' {
        $d = New-NSPScheduledTaskDefinition -TaskName 'Daily' -Execute 'x.exe' -RunAs SYSTEM -Trigger (New-ScheduledTaskTrigger -Daily -At '22:00')
        Mock -ModuleName NSP.Win.ScheduledTask Get-ScheduledTask { Get-FakeInstalledTask -Definition $d -Triggers (New-ScheduledTaskTrigger -Daily -At ((Get-Date).Date.AddDays(-30).AddHours(22))) }
        ($d | Test-NSPScheduledTask).InSync | Should -BeTrue
        Mock -ModuleName NSP.Win.ScheduledTask Get-ScheduledTask { Get-FakeInstalledTask -Definition $d -Triggers (New-ScheduledTaskTrigger -Daily -At '23:00') }
        ($d | Test-NSPScheduledTask).Differences | Should -Contain "Trigger 1 time: expected '22:00:00', found '23:00:00'"
    }
    It 'reports a missing task' {
        Mock -ModuleName NSP.Win.ScheduledTask Get-ScheduledTask { }
        $r = $script:def | Test-NSPScheduledTask
        $r.Exists | Should -BeFalse
        $r.Differences | Should -Be @('Task not found.')
    }
}
