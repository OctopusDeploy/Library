[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$OctopusAPIKey = $OctopusParameters["RegisterListeningWorker.Octopus.Api.Key"]
$RegistrationName = $OctopusParameters["RegisterListeningWorker.Machine.Name"]
$RegistrationAddress = $OctopusParameters["RegisterListeningWorker.Machine.Address"]
$OctopusUrl = $OctopusParameters["RegisterListeningWorker.Octopus.Base.Url"]
$WorkerPools = $OctopusParameters["RegisterListeningWorker.WorkerPool.List"]
$SpaceId = $OctopusParameters["Octopus.Space.Id"]
$MachinePolicyIdOrName = $OctopusParameters["RegisterListeningWorker.MachinePolicy.IdOrName"]
$PortNumber = $OctopusParameters["RegisterListeningWorker.Machine.Port"]
$OverwriteExisting = $OctopusParameters["RegisterListeningWorker.Overwrite.Existing"]
$OverwriteExisting = $OverwriteExisting -eq "True"


Write-Host "Machine Name: $RegistrationName"
Write-Host "Machine Address: $RegistrationAddress"
Write-Host "Machine Port: $PortNumber"
Write-Host "Octopus Url: $OctopusUrl"
Write-Host "Worker Pools: $WorkerPools"
Write-Host "Environments: $Environments"
Write-Host "Machine Policy Name or Id: $MachinePolicyIdOrName"
Write-Host "Overwrite Existing: $OverwriteExisting"

$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("X-Octopus-ApiKey", $OctopusAPIKey)

$baseApiUrl = "$OctopusUrl/api"
$baseApiInformation = Invoke-RestMethod $baseApiUrl -Headers $header
if ((Get-Member -InputObject $baseApiInformation.Links -Name "Spaces" -MemberType Properties) -ne $null)
{  	
	$baseApiUrl = "$baseApiUrl/$SpaceId"    
}

Write-Host "Base API Url: $baseApiUrl"

$existingMachineResultsUrl = "$baseApiUrl/workers?partialName=$RegistrationName&skip=0&take=1000"
Write-Host "Attempting to find existing machine with similar name at $existingMachineResultsUrl"
$existingMachineResponse = Invoke-RestMethod $existingMachineResultsUrl -Headers $header
Write-Host $existingMachineResponse

$machineFound = $false
foreach ($item in $existingMachineResponse.Items)
{
	if ($item.Name -eq $RegistrationName)
    {
    	$machineFound = $true
        if ($OverwriteExisting)
        {
        	$machineId = $item.Id 
        }
        break
    }
}

if ($machineFound -and $OverwriteExisting -eq $false)
{
	Write-Highlight "Machine already exists, skipping registration"
    Exit 0
}

$workerPoolList = $WorkerPools -split ","
$workerPoolIdList = @()
Write-Host "Getting the ids for all environments specified"
foreach($workerPool in $workerPoolList)
{
	Write-Host "Getting the id for the worker pool $workerPool"
    
    if ($workerPool.StartsWith("WorkerPools-") -eq $true)
    {
    	Write-Host "The worker pool is already an id, using that instead of looking it up"
    	$workerPoolIdList += $workerPool
    }
    else
    {
    	$workerPoolEscaped = $workerPool.Replace(" ", "%20")
        $workerPoolUrl = "$baseApiUrl/workerpools?skip=0&take=1000&partialName=$workerPoolEscaped"
        $workerPoolResponse = Invoke-RestMethod $workerPoolUrl -Headers $header 

        $workerPoolId = $workerPoolResponse.Items[0].Id
        Write-Host "The id for worker pool $workerPool is $workerPoolId"
        $workerPoolIdList += $workerPoolId
    }       
}

$machinePolicyId = $machinePolicyIdOrName
if ($machinePolicyIdOrName.StartsWith("MachinePolicies-") -eq $false)
{
	Write-Host "The machine policy specified $machinePolicyIdOrName appears to be a name"
	$machinePolicyNameEscaped = $machinePolicyIdOrName.Replace(" ", "%20")
	$machinePolicyResponse = Invoke-RestMethod "$baseApiUrl/machinepolicies?partialName=$machinePolicyNameEscaped" -Headers $header
        
    $machinePolicyId = $machinePolicyResponse.Items[0].Id
    Write-Host "The machine policy id is $machinePolicyId"
}

$discoverUrl = "$baseApiUrl/machines/discover?host=$RegistrationAddress&port=$PortNumber&type=TentaclePassive"
Write-Host "Discovering the machine $discoverUrl"
$discoverResponse = Invoke-RestMethod $discoverUrl -Headers $header 
Write-Host "ProjectResponse: $discoverResponse"

$machineThumbprint = $discoverResponse.EndPoint.Thumbprint
Write-Host "Thumbprint = $machineThumbprint"

$rawRequest = @{
  Id = $machineId;
  MachinePolicyId = $MachinePolicyId;
  Name = $RegistrationName;
  IsDisabled = $false;
  HealthStatus = "Unknown";
  HasLatestCalamari = $true;
  StatusSummary = $null;
  IsInProcess = $true;
  Links = $null;
  WorkerPoolIds = $workerPoolIdList;
  Endpoint = @{
    Id = $null;
    CommunicationStyle = "TentaclePassive";
    Links = $null;
    Uri = "https://$RegistrationAddress`:$PortNumber";
    Thumbprint = "$machineThumbprint";
    ProxyId = $null
  }
}

$jsonRequest = $rawRequest | ConvertTo-Json -Depth 10

Write-Host "Sending in the request $jsonRequest"

$machineUrl = "$baseApiUrl/workers"
$method = "POST"
if ($OverwriteExisting -and $machineId -ne $null)
{
	$machineUrl = "$machineUrl/$machineId" 
  	$method = "PUT"
}

Write-Host "Posting to url $machineUrl"
$machineResponse = Invoke-RestMethod $machineUrl -Headers $header -Method $method -Body $jsonRequest

Write-Host "Create workers's response: $machineResponse"