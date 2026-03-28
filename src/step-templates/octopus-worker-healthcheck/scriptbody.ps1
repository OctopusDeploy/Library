# Define parameters
$baseUrl = $OctopusParameters['Octopus.Web.ServerUri'] 
$apiKey = $WorkerApiKey
$spaceId = $OctopusParameters['Octopus.Space.Id']
$spaceName = $OctopusParameters['Octopus.Space.Name']
$environmentName = $OctopusParameters['Octopus.Environment.Name']
$workerName = $OctopusParameters['WorkerName']
$workerPoolName = $OctopusParameters['WorkerPoolName']

# Check for null or empty
if ([string]::IsNullOrEmpty($baseUrl))
{
	$baseUrl = $OctopusParameters['#{if Octopus.Web.ServerUri}Octopus.Web.ServerUri#{else}Octopus.Web.BaseUrl#{/if}']
}

# Get worker
if (![string]::IsNullOrEmpty($workerPoolName))
{
    # Get worker pool
    $workerPool = (Invoke-RestMethod -Method Get -Uri "$baseUrl/api/$spaceId/workerpools/all" -Headers @{"X-Octopus-ApiKey"="$apiKey"}) | Where-Object {$_.Name -eq $workerPoolName}
    
    # Check to make sure it exists
    if ($null -ne $workerPool)
    {
        $worker = (Invoke-RestMethod -Method Get -Uri "$baseUrl/api/$spaceId/workerpools/$($workerPool.Id)/workers" -Headers @{"X-Octopus-ApiKey"="$apiKey"}).Items | Where-Object {$_.Name -eq "$workerName"}
    }
    else
    {
    	Write-Error "Worker pool $workerPoolName not found!"
    }
}
else
{
    $worker = (Invoke-RestMethod -Method Get -Uri "$baseUrl/api/$spaceId/workers/all" -Headers @{"X-Octopus-ApiKey"="$apiKey"}) | Where-Object {$_.Name -eq "$workerName"}
}

# Check to make sure something was returned
if ($null -eq $worker)
{
	if (![string]::IsNullOrEmpty($workerPoolName))
    {
    	Write-Error "Unable to find $workerName in $workerPoolName!"
    }
    else
    {
    	Write-Error "Unable to find $workerName!"
    }
}

# Build payload
$jsonPayload = @{
	Name = "Health"
    Description = "Check $workerName health"
    Arguments = @{
    	Timeout = "00:05:00"
        MachineIds = @(
        	$worker.Id
        )
    OnlyTestConnection = "false"
    }
    SpaceId = "$spaceId"
}

# Display message
Write-Output "Beginning health check of $workerName ..."

# Execute health check
$healthCheck = (Invoke-RestMethod -Method Post -Uri "$baseUrl/api/tasks" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers @{"X-Octopus-ApiKey"="$apiKey"})

# Check to see if the health check is queued
while ($healthCheck.IsCompleted -eq $false)
{
    $healthCheck = (Invoke-RestMethod -Method Get -Uri "$baseUrl/api/tasks/$($healthCheck.Id)" -Headers @{"X-Octopus-ApiKey"="$apiKey"})
}

if ($healthCheck.State -eq "Failed")
{
	Write-Error "Health check failed!"
}
else
{
	Write-Output "Health check completed with $($healthCheck.State)."
}
