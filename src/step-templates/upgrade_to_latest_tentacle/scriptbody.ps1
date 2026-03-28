# Define working variables
$OctopusUrl       = [string]$OctopusParameters['UpdateTentacles.OctopusUrl'].Trim()
$ApiKey           = [string]$OctopusParameters['UpdateTentacles.ApiKey'].Trim()
$SpaceName        = [string]$OctopusParameters['UpdateTentacles.SpaceName'].Trim()
$EnvironmentNames = [string[]]$OctopusParameters['UpdateTentacles.EnvironmentNames']
$RoleNames        = [string[]]$OctopusParameters['UpdateTentacles.RoleNames']
$MachineNames     = [string[]]$OctopusParameters['UpdateTentacles.MachineNames']
$WhatIf           = [bool]::Parse($OctopusParameters['UpdateTentacles.WhatIf'])
$Wait             = [bool]::Parse($OctopusParameters['UpdateTentacles.Wait'])

# Remove white space and blank lines.
if ($null -ne $EnvironmentNames) {
    $EnvironmentNames = $EnvironmentNames.Split("`n").Trim().Where({$_}) # Trim white space and blank lines.
}
if ($null -ne $RoleNames) {
    $RoleNames = $RoleNames.Split("`n").Trim().Where({$_}) # Trim white space and blank lines.
}
if ($null -ne $MachineNames) {
    $MachineNames = $MachineNames.Split("`n").Trim().Where({$_}) # Trim white space and blank lines.
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$header = @{ "X-Octopus-ApiKey" = $ApiKey }

if ($null -eq $SpaceName) {
    $baseUri = "$OctopusUrl/api"
} else {
    $space = (Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $SpaceName }

    if ($null -eq $space) {
        throw "Space Name $SpaceName does not exist."
    } else {
        Write-Verbose "Using Space $SpaceName."
    }

    $baseUri = "$OctopusUrl/api/$($space.Id)"
}

# Start with no machines
$allMachines = @()

# Add machines for each requested environment.
foreach ($environmentName in $EnvironmentNames) {
    $environment = (Invoke-RestMethod -Method Get -Uri "$baseUri/environments/all" -Headers $header) | Where-Object { $_.Name -eq $environmentName }

    if ($null -eq $environment) {
        throw "Environment $environmentName does not exist."
    } else {
        Write-Verbose "Adding machines from Environment $environmentName."
    }

    $allMachines += (Invoke-RestMethod -Method Get -Uri "$baseUri/environments/$($environment.Id)/machines?take=$([int32]::MaxValue)" -Headers $header).Items
}

# If roles are specifed, include only machines in the specicied roles. Otherwise don't filter.
if ($null -eq $RoleNames) {
    $roleFilteredMachines += $allMachines
} else {
    $roleFilteredMachines = @()
    foreach ($roleName in $RoleNames) {
        $roleFilteredMachines += $allMachines | Where-Object { $_.Roles -contains $roleName }
    }
}

# Add each specific machine requested.
$roleFilteredMachines += (Invoke-RestMethod -Method Get -Uri "$baseUri/machines/all" -Headers $header) | Where-Object { $_.Name -in $MachineNames }

# Create array of unique IDs to target.
$uniqueIDs = [array]($roleFilteredMachines.Id | Sort-Object -Unique)

if (-not $uniqueIDs) {
    Write-Highlight "No machines were targeted. Exiting..."
    exit
}

# Build json payload, targeting unique machine IDs.
$jsonPayload = @{
    Arguments = @{
        MachineIds = $uniqueIDs
    }
    Description = "Upgrade Tentacle version."
    Name = "Upgrade"
}

if ($WhatIf) {
    Write-Host "Upgrading tentacles on:"
    Write-Host $(($roleFilteredMachines.Name | Sort-Object -Unique) -join "`r")
} else {
    Write-Verbose "Upgrading tentacles on:"
    Write-Verbose $(($roleFilteredMachines.Name | Sort-Object -Unique) -join "`r")
    $task = Invoke-RestMethod -Method Post -Uri "$baseUri/tasks" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)
    Write-Highlight "$($task.Id) started. Progress can be monitored [here]($OctopusUrl$($task.Links.Web)?activeTab=taskLog)"
    
    if ($Wait) {
        do {
        	# Output the current state of the task every five seconds.
            $task = Invoke-RestMethod -Method Get -Uri "$baseUri/tasks/$($task.Id)" -Headers $header
            $task
            Start-Sleep -Seconds 5
        } while ($task.IsCompleted -eq $false)
    }
}