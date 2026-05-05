# Running outside octopus
Param(
    [string] $AD_AddHostsEntry_HostName,
    [string] $AD_AddHostsEntry_IpAddress = "127.0.0.1",
    [Int16] $AD_AddHostsEntry_Attempts = 5,
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
    [Parameter(Mandatory = $true)][string] $HostName,
    [Parameter(Mandatory = $false)][string] $IpAddress = "127.0.0.1",
    [Parameter(Mandatory = $false)][Int16] $Attempts = 5
) {
    $attemptCount = 0
    $operationIncomplete = $true
    $maxFailures = $Attempts
    $sleepBetweenFailures = 1

    $hostsFile = "$($env:windir)\system32\Drivers\etc\hosts"
    $entry = "$IpAddress $HostName"
    $regexMatch = "^\s*$IpAddress\s+$HostName"
    while ($operationIncomplete -and $attemptCount -lt $maxFailures) {
        $attemptCount = ($attemptCount + 1)
        if ($attemptCount -ge 2) {
            Write-Output "Waiting for $sleepBetweenFailures seconds before retrying..."
            Start-Sleep -s $sleepBetweenFailures
            Write-Output "Retrying..."
            $sleepBetweenFailures = ($sleepBetweenFailures * 2)
        }
        try {
            $matchingEntries = @(Get-Content $hostsFile) -match ($regexMatch)
            if (-Not $matchingEntries) {
                Write-Output "Entry '$entry' doesn't exist - ADDING..."
                if (-Not ($WhatIf)) {
                    $formattedEntry = [environment]::newline + $entry
                    [System.IO.File]::AppendAllText($hostsFile, $formattedEntry)
                }
                Write-Output "Entry '$entry' - ADDED"
            }
            else {
                Write-Output "Entry '$entry' already exists - SKIPPING"
            }
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
(Get-Param 'AD_AddHostsEntry_HostName' -Required)`
(Get-Param 'AD_AddHostsEntry_IpAddress')`
(Get-Param 'AD_AddHostsEntry_Attempts')
