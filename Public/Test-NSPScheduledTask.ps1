function Test-NSPScheduledTask {
    <#
    .SYNOPSIS
        Checks an installed scheduled task against its New-NSPScheduledTaskDefinition and lists every difference.
    .DESCRIPTION
        Compares the action (program, arguments, working folder), the account and run level, the
        description, the settings this module sets, and the triggers (type, schedule time or event
        query, enabled). InSync is true when the task exists and nothing differs. Read-only.
    .EXAMPLE
        $def | Test-NSPScheduledTask | Format-List TaskName, InSync, Differences
    #>
    [CmdletBinding()]
    [OutputType('NSP.Win.ScheduledTask.TestResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][PSTypeName('NSP.Win.ScheduledTask.Definition')]$Definition
    )

    process {
        $d = $Definition
        $diff = [System.Collections.Generic.List[string]]::new()
        $task = Get-ScheduledTask -TaskName $d.TaskName -TaskPath $d.TaskPath -ErrorAction SilentlyContinue
        $result = [ordered]@{ PSTypeName = 'NSP.Win.ScheduledTask.TestResult'; TaskName = $d.TaskName; TaskPath = $d.TaskPath; Exists = [bool]$task; InSync = $false; Differences = @() }
        if (-not $task) {
            $result.Differences = @('Task not found.')
            return [pscustomobject]$result
        }
        $check = {
            param([string]$What, $Want, $Have)
            if ("$Want" -ne "$Have") { $diff.Add("$What`: expected '$Want', found '$Have'") }
        }

        $actions = @($task.Actions)
        if ($actions.Count -ne 1) { $diff.Add("Actions: expected 1, found $($actions.Count)") }
        else {
            & $check 'Program' $d.Execute $actions[0].Execute
            & $check 'Arguments' $d.Argument $actions[0].Arguments
            & $check 'Working folder' $d.WorkingDirectory $actions[0].WorkingDirectory
        }
        if ($d.Description) { & $check 'Description' $d.Description $task.Description }

        # The task stores a gMSA as 'name$' (no domain) and SYSTEM by name or SID.
        $wantUser = if ($d.AccountKind -eq 'System') { 'SYSTEM' } else { ($d.RunAs -split '\\')[-1] }
        $haveUser = ([string]$task.Principal.UserId -split '\\')[-1]
        if ($d.AccountKind -eq 'System' -and $haveUser -eq 'S-1-5-18') { $haveUser = 'SYSTEM' }
        & $check 'Account' $wantUser $haveUser
        & $check 'Run level' $d.RunLevel $task.Principal.RunLevel
        if ($d.AccountKind -eq 'ManagedServiceAccount') { & $check 'Logon type' 'Password' $task.Principal.LogonType }

        & $check 'Time limit' ([Xml.XmlConvert]::ToString($d.ExecutionTimeLimit)) $task.Settings.ExecutionTimeLimit
        & $check 'Multiple instances' $d.MultipleInstances $task.Settings.MultipleInstances
        & $check 'Wake to run' $d.WakeToRun ([bool]$task.Settings.WakeToRun)

        $want = @($d.Trigger)
        $have = @($task.Triggers)
        if ($want.Count -ne $have.Count) { $diff.Add("Triggers: expected $($want.Count), found $($have.Count)") }
        else {
            for ($i = 0; $i -lt $want.Count; $i++) {
                $label = "Trigger $($i + 1)"
                & $check "$label type" $want[$i].CimClass.CimClassName $have[$i].CimClass.CimClassName
                & $check "$label enabled" ([bool]$want[$i].Enabled) ([bool]$have[$i].Enabled)
                if ($want[$i].CimClass.CimClassName -eq 'MSFT_TaskEventTrigger') {
                    & $check "$label event query" $want[$i].Subscription $have[$i].Subscription
                } elseif ($want[$i].StartBoundary -and $have[$i].StartBoundary) {
                    # Compare the time of day: the date part is just the first run.
                    & $check "$label time" ([datetime]$want[$i].StartBoundary).ToString('HH:mm:ss') ([datetime]$have[$i].StartBoundary).ToString('HH:mm:ss')
                }
                if ($want[$i].PSObject.Properties['DaysInterval']) { & $check "$label days interval" $want[$i].DaysInterval $have[$i].DaysInterval }
            }
        }

        $result.Differences = @($diff)
        $result.InSync = ($diff.Count -eq 0)
        [pscustomobject]$result
    }
}
