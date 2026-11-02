function New-NSPEventTaskTrigger {
    <#
    .SYNOPSIS
        Builds an "on an event" scheduled-task trigger (the kind New-ScheduledTaskTrigger can't make).
    .DESCRIPTION
        Give a log and event ID (and optionally the provider), or a complete -Subscription query
        (QueryList XML, as Event Viewer's "Custom" filter writes it). The trigger fires once per
        matching event; pair it with MultipleInstances IgnoreNew or Queue in the definition so a
        burst of events doesn't start a burst of runs.

        A common use: Sysmon event 11 (FileCreate) on a watched folder, to run a job as soon as a
        file lands.
    .PARAMETER ValueQuery
        Optional map of names to event XPath expressions. Task actions can reference these
        named values; omitting the map preserves existing behavior.
    .EXAMPLE
        New-NSPEventTaskTrigger -LogName 'Microsoft-Windows-Sysmon/Operational' -EventId 11 -Provider 'Microsoft-Windows-Sysmon'
    .EXAMPLE
        New-NSPEventTaskTrigger -Subscription '<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[EventID=1000]]</Select></Query></QueryList>'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an object in memory; nothing on the system changes.')]
    [CmdletBinding(DefaultParameterSetName = 'Event')]
    [OutputType([ciminstance])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Event')][string]$LogName,
        [Parameter(Mandatory, ParameterSetName = 'Event')][int[]]$EventId,
        [Parameter(ParameterSetName = 'Event')][string]$Provider,
        [Parameter(Mandatory, ParameterSetName = 'Subscription')][string]$Subscription,
        [timespan]$Delay,
        [System.Collections.IDictionary]$ValueQuery
    )

    if ($PSCmdlet.ParameterSetName -eq 'Event') {
        $escape = { param($s) [Security.SecurityElement]::Escape($s) }
        $ids = ($EventId | ForEach-Object { "EventID=$_" }) -join ' or '
        $system = if ($Provider) { "Provider[@Name='$(& $escape $Provider)'] and ($ids)" } else { $ids }
        $log = & $escape $LogName
        $Subscription = "<QueryList><Query Id=`"0`" Path=`"$log`"><Select Path=`"$log`">*[System[$system]]</Select></Query></QueryList>"
    }
    try { [void][xml]$Subscription } catch { throw "Subscription is not valid XML: $($_.Exception.Message)" }

    $queries = @()
    if ($ValueQuery) {
        foreach ($name in $ValueQuery.Keys) {
            if ([string]$name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw 'Value-query names must be identifiers.' }
            $xpath = [string]$ValueQuery[$name]
            if ([string]::IsNullOrWhiteSpace($xpath)) { throw 'Value-query XPath cannot be empty.' }
            try { $null = [Xml.XPath.XPathExpression]::Compile($xpath) } catch { throw 'Invalid value-query XPath.' }
        }
        $valueClass = Get-CimClass -ClassName MSFT_TaskNamedValue -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ErrorAction Stop
        $queries = @(foreach ($name in @($ValueQuery.Keys | Sort-Object)) {
            New-CimInstance -CimClass $valueClass -ClientOnly -Property @{Name=[string]$name; Value=[string]$ValueQuery[$name]}
        })
    }
    $class = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ErrorAction Stop
    $trigger = New-CimInstance -CimClass $class -ClientOnly
    $trigger.Enabled = $true
    $trigger.Subscription = $Subscription
    if ($queries.Count) { $trigger.ValueQueries = [ciminstance[]]$queries }
    if ($Delay) { $trigger.Delay = [Xml.XmlConvert]::ToString($Delay) }
    $trigger
}
