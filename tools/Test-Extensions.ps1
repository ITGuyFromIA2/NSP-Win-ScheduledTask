[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets','',Justification='Offline contract intentionally shadows commands and accepts their signature; no live changes.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter','',Justification='Offline contract intentionally shadows commands and accepts their signature; no live changes.')]
[CmdletBinding()]
param([string]$SourceRoot)
$ErrorActionPreference='Stop'
if(-not $SourceRoot){$SourceRoot=Split-Path -Parent $PSScriptRoot}
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
. (Join-Path $SourceRoot 'Public/New-NSPEventTaskTrigger.ps1')
. (Join-Path $SourceRoot 'Public/New-NSPScheduledTaskDefinition.ps1')
. (Join-Path $SourceRoot 'Public/Test-NSPScheduledTask.ps1')
$checks=0
function Check($condition,$message) { if(-not $condition) { throw $message }; $script:checks++ }
function Reject([scriptblock]$action) { $failed=$false;try { &$action|Out-Null }catch{$failed=$true};Check $failed 'Expected validation rejection.' }
$trigger=New-NSPEventTaskTrigger -LogName 'Microsoft-Windows-Sysmon/Operational' -EventId 11 -ValueQuery @{RecordId='Event/System/EventRecordID';File='Event/EventData/Data[@Name="TargetFilename"]'} -Delay (New-TimeSpan -Seconds 5)
Check ($trigger.ValueQueries.Count -eq 2) 'Embedded event queries missing.'
Check ($trigger.ValueQueries[0].Name -eq 'File' -and $trigger.ValueQueries[1].Value -eq 'Event/System/EventRecordID') 'Event query map changed.'
Check ($trigger.Delay -eq 'PT5S') 'Event delay changed.'
$plain=New-NSPEventTaskTrigger -LogName Application -EventId 1000
Check (-not $plain.ValueQueries) 'Omitted queries changed default.'
Reject {New-NSPEventTaskTrigger -LogName Application -EventId 1 -ValueQuery @{'Bad-Name'='Event/System/EventRecordID'}}
Reject {New-NSPEventTaskTrigger -LogName Application -EventId 1 -ValueQuery @{RecordId='['}}
Reject {New-NSPEventTaskTrigger -LogName Application -EventId 1 -ValueQuery @{RecordId=''}}
$definition=New-NSPScheduledTaskDefinition -TaskName 'Synthetic' -Execute 'powershell.exe' -RunAs SYSTEM -Trigger $trigger -StartWhenAvailable
$fakeTask=[pscustomobject]@{
    Actions=@([pscustomobject]@{Execute=$definition.Execute;Arguments=$definition.Argument;WorkingDirectory=$definition.WorkingDirectory})
    Principal=[pscustomobject]@{UserId='S-1-5-18';RunLevel=$definition.RunLevel}
    Settings=[pscustomobject]@{ExecutionTimeLimit='PT1H';MultipleInstances='IgnoreNew';WakeToRun=$false;StartWhenAvailable=$true}
    Triggers=@([Microsoft.Management.Infrastructure.CimInstance]::new($trigger))
}
$repeat=New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
function Get-ScheduledTask { [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets','',Justification='Offline contract intentionally shadows commands and accepts their signature; no live changes.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter','',Justification='Offline contract intentionally shadows commands and accepts their signature; no live changes.')]
[CmdletBinding()]param($TaskName,$TaskPath) $fakeTask }
Check ((Test-NSPScheduledTask $definition).InSync) 'Matching task drifted.'
$fakeTask.Settings.StartWhenAvailable=$false
Check (-not (Test-NSPScheduledTask $definition).InSync) 'StartWhenAvailable drift missed.'
$fakeTask.Settings.StartWhenAvailable=$true
$fakeTask.Triggers[0].ValueQueries=@()
Check (-not (Test-NSPScheduledTask $definition).InSync) 'Event value drift missed.'
$fakeTask.Triggers=@([Microsoft.Management.Infrastructure.CimInstance]::new($trigger))
$fakeTask.Triggers[0].Delay='PT9S'
Check (-not (Test-NSPScheduledTask $definition).InSync) 'Delay drift missed.'
$definition.Trigger=@($repeat)
$fakeTask.Triggers=@([Microsoft.Management.Infrastructure.CimInstance]::new($repeat))
$matchingRepeat=Test-NSPScheduledTask $definition
Check $matchingRepeat.InSync ('Matching repeating task drifted: '+($matchingRepeat.Differences -join '; '))
$fakeTask.Triggers[0].Repetition.Interval='PT10M'
Check (-not (Test-NSPScheduledTask $definition).InSync) 'Repeat interval drift missed.'
Write-Host ('Passed: {0} scheduling-helper checks in {1}; real client-only CIM objects, no registration.' -f $checks,$PSVersionTable.PSVersion)
