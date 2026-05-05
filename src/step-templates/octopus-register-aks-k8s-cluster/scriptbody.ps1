[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$OctopusAPIKey = $OctopusParameters["RegisterAzureCluster.Octopus.Api.Key"]
$RegistrationName = $OctopusParameters["RegisterAzureCluster.AKS.Name"]
$ClusterResourceGroup = $OctopusParameters["RegisterAzureCluster.ResourceGroup.Name"]
$OctopusUrl = $OctopusParameters["RegisterAzureCluster.Octopus.Base.Url"]
$Roles = $OctopusParameters["RegisterAzureCluster.Roles.List"]
$Environments = $OctopusParameters["RegisterAzureCluster.Environment.List"]
$SpaceId = $OctopusParameters["Octopus.Space.Id"]
$MachinePolicyIdOrName = $OctopusParameters["RegisterAzureCluster.MachinePolicy.IdOrName"]
$AzureAccountId = $OctopusParameters["RegisterAzureCluster.Azure.Account"]
$Tenants = $OctopusParameters["RegisterAzureCluster.Tenant.List"]
$DeploymentType = $OctopusParameters["RegisterAzureCluster.Tenant.DeploymentType"]
$WorkerPoolNameOrId = $OctopusParameters["RegisterAzureCluster.WorkerPool.IdOrName"]
$OverwriteExisting = $OctopusParameters["RegisterAzureCluster.Overwrite.Existing"]
$OverwriteExisting = $OverwriteExisting -eq "True"

Write-Host "AKS Name: $RegistrationName"
Write-Host "Resoure Group Name: $ClusterResourceGroup"
Write-Host "Octopus Url: $OctopusUrl"
Write-Host "Role List: $Roles"
Write-Host "Environments: $Environments"
Write-Host "Machine Policy Name or Id: $MachinePolicyIdOrName"
Write-Host "Azure Account Id: $AzureAccountId"
Write-Host "Tenant List: $Tenants"
Write-Host "Deployment Type: $DeploymentType"
Write-Host "Worker Pool Name or Id: $WorkerPoolNameOrId"
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

$existingMachineResultsUrl = "$baseApiUrl/machines?partialName=$RegistrationName&skip=0&take=1000"
Write-Host "Attempting to find existing machine with similar name at $existingMachineResultsUrl"
$existingMachineResponse = Invoke-RestMethod $existingMachineResultsUrl -Headers $header
Write-Host $existingMachineResponse

$machineFound = $false
$machineId = $null
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

$roleList = $Roles -split ","
$environmentList = $Environments -split ","
$environmentIdList = @()
Write-Host "Getting the ids for all environments specified"
foreach($environment in $environmentList)
{
	Write-Host "Getting the id for the environment $environment"
    $environmentEscaped = $environment.Replace(" ", "%20")
    $environmentUrl = "$baseApiUrl/environments?skip=0&take=1000&name=$environmentEscaped"
    $environmentResponse = Invoke-RestMethod $environmentUrl -Headers $header 

    $environmentId = $environmentResponse.Items[0].Id
    if ($environmentId -eq $null)
    {
    	Write-Host "The environment $environment cannot be found in this space, exiting"
        exit 1
    }
    Write-Host "The id for environment $environment is $environmentId"
    $environmentIdList += $environmentId
}
$tenantList = $Tenants -split ","
$tenantIdList = @()

foreach($tenant in $tenantList)
{
	if ([string]::IsNullOrWhiteSpace($tenant) -eq $false)
    {    
      Write-Host "Getting the id for tenant $tenant"
      $tenantEscaped = $tenant.Replace(" ", "%20")
      $tenantUrl = "$baseApiUrl/tenants?skip=0&take=1000&name=$tenantEscaped"
      $tenantResponse = Invoke-RestMethod $tenantUrl -Headers $header 

      $tenantId = $tenantResponse.Items[0].Id
      Write-Host "The id for tenant $tenant is $tenantId"
      $tenantIdList += $tenantId
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

if ([string]::IsNullOrWhiteSpace($machinePolicyId) -eq $true)
{
	Write-Host "The machine policy $machinePolicyIdOrName cannot be found, exiting"
    exit 1
}

$workerPoolId = $WorkerPoolNameOrId
if ([string]::IsNullOrWhiteSpace($workerPoolId) -eq $false -and $workerPoolId.StartsWith("WorkerPools-") -eq $false)
{
	Write-Host "The worker pool $workerPoolId appears to be a name, looking it up"
    $workerPoolNameEscaped = $workerPoolId.Replace(" ", "%20")
    $workerPoolResponse = Invoke-RestMethod "$baseApiUrl/workerpools?partialName=$workerPoolNameEscaped" -Headers $header
    
    $workerPoolId = $workerPoolResponse.Items[0].Id
    Write-Host "The worker pool id is $workerPoolId"
}

$rawRequest = @{
	Id = $machineId;
    MachinePolicyId = $MachinePolicyId;
    Name = $RegistrationName;
	IsDisabled = $false;
	HealthStatus = "Unknown";
	HasLatestCalamari = $true;
	StatusSummary = $null;
	IsInProcess = $true;
	Endpoint = @{
    	Id = $null;
		CommunicationStyle = "Kubernetes";
		Links = $null;
		AccountType = "AzureServicePrincipal";
        ClusterUrl = $null;
        ClusterCertificate = $null;
        SkipTlsVerification = $false;
        DefaultWorkerPoolId = $workerPoolId;
        Authentication = @{
        	AuthenticationType = "KubernetesAzure";
            AccountId = $AzureAccountId;
            ClusterName = $RegistrationName;
            ClusterResourceGroup = $ClusterResourceGroup
        };
    };
	Links = $null;	
	Roles = $roleList;
	EnvironmentIds = $environmentIdList;
	TenantIds = $tenantIdList;
    TenantedDeploymentParticipation = $DeploymentType;
	TenantTags = @()}

$jsonRequest = $rawRequest | ConvertTo-Json -Depth 10

Write-Host "Sending in the request $jsonRequest"

$machineUrl = "$baseApiUrl/machines"
$method = "POST"
if ($OverwriteExisting -and $machineId -ne $null)
{
	$machineUrl = "$machineUrl/$machineId" 
  	$method = "PUT"
}

Write-Host "Posting to url $machineUrl"
$machineResponse = Invoke-RestMethod $machineUrl -Headers $header -Method $method -Body $jsonRequest

Write-Host "Create machine's response: $machineResponse"