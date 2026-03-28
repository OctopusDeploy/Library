# Running outside octopus
Param(
    [string] $AD_PollRestEndpoint_Uri,
    [string] $AD_PollRestEndpoint_Name = "Polling task for endpoint",
    [string] $AD_PollRestEndpoint_HttpMethod = "GET",
    [string] $AD_PollRestEndpoint_Interval = 60,
    [Int16] $AD_PollRestEndpoint_Attempts = 5,
    [switch] $WhatIf
)

$ErrorActionPreference = "Stop"

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($null -ne $OctopusParameters) {
        $result = $OctopusParameters[$Name]
    }

    if ($null -eq $result) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($null -ne $variable) {
            $result = $variable.Value
        }
    }

    if ($null -eq $result) {
        if ($Required) {
            throw "Missing parameter value $Name"
        }
        else {
            $result = $Default
        }
    }

    return $result
}
function Execute(
    [Parameter(Mandatory = $true)][string] $Uri,
    [Parameter(Mandatory = $false)][string] $Name = "Polling task for endpoint",
    [Parameter(Mandatory = $false)][string] $HttpMethod = "GET",
    [Parameter(Mandatory = $false)][string] $Interval = 60,
    [Parameter(Mandatory = $false)][Int16] $Attempts = 5
) {
    $attemptCount = 0
    $operationIncomplete = $true
    $maxFailures = $Attempts
    $sleepBetweenFailures = 1

    $script = '-noprofile -executionpolicy bypass -command "& { Invoke-RestMethod -Uri ' + $Uri + ' -Method ' + $HttpMethod + ' }"'
    $repeat = (New-TimeSpan -Seconds $Interval)

    $action = New-ScheduledTaskAction "powershell.exe" -Argument  "$script"
    $duration = (New-TimeSpan -Days 9999)
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval $repeat -RepetitionDuration $duration
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd

    while ($operationIncomplete -and $attemptCount -lt $maxFailures) {
        $attemptCount = ($attemptCount + 1)
        if ($attemptCount -ge 2) {
            Write-Output "Waiting for $sleepBetweenFailures seconds before retrying..."
            Start-Sleep -s $sleepBetweenFailures
            Write-Output "Retrying..."
            $sleepBetweenFailures = ($sleepBetweenFailures * 2)
        }
        try {
            $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
            Write-Output $task
            $msg = "Task '$Name'"
            if ($null -ne $task) {
                Write-Output "$msg already exists - DELETING..."
                if (-Not ($WhatIf)) {
                    Unregister-ScheduledTask -TaskName $name -Confirm:$false
                }
                Write-Output "$msg - DELETED"
            }
            Write-Output "$msg - ADDING..."
            if (-Not ($WhatIf)) {
                Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -RunLevel Highest -Settings $settings -User "System"
            }
            Write-Output "$msg - ADDED"
            $operationIncomplete = $false
        }
        catch [System.Exception] {
            if ($attemptCount -lt ($maxFailures)) {
                Write-Host ("Attempt $attemptCount of $maxFailures failed: " + $_.Exception.Message)
            }
            else {
                throw
            }
        }
    }
}
& Execute `
(Get-Param 'AD_PollRestEndpoint_Uri' -Required)`
(Get-Param 'AD_PollRestEndpoint_Name')`
(Get-Param 'AD_PollRestEndpoint_HttpMethod')`
(Get-Param 'AD_PollRestEndpoint_Interval')`
(Get-Param 'AD_PollRestEndpoint_Attempts')
