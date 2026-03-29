$securityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = $securityProtocol

$ErrorActionPreference = 'Stop'

$octopusBaseUrl = $CloneTenantStep_OctopusUrl.Trim('/')
$apiKey = $CreateTenantStep_ApiKey
$tenantName = $CreateTenantStep_TenantName
$tenantTags = if ($CreateTenantStep_TenantTags -eq $null) { @() } else { $CreateTenantStep_TenantTags | ConvertFrom-Json }
$projectEnvironments = if ($CreateTenantStep_ProjectEnvironments -eq $null) { @{} } else { $CreateTenantStep_ProjectEnvironments | ConvertFrom-Json }
$spaceId = $CloneTenantStep_SpaceId

if ([string]::IsNullOrWhiteSpace($octopusBaseUrl)) {
    throw "The step parameter 'Octopus Base Url' was not found. This step requires the Octopus Server URL to function, please provide one and try again."
}

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "The step parameter 'Octopus API Key' was not found. This step requires an API Key to function, please provide one and try again."
}

if ([string]::IsNullOrWhiteSpace($tenantName)) {
    throw "The step parameter 'Tenant Name' was not found. Please provide one and try again."
}

function Invoke-OctopusApi {
    param(
        [Parameter(Position = 0, Mandatory)]$Uri,
        [ValidateSet("Get", "Post", "Put", "Delete")]$Method = 'Get',
        $Body
    )
    
    $uriParts = @($octopusBaseUrl, $Uri.TrimStart('/'))    
    $uri = ($uriParts -join '/')
    
    Write-Verbose "Uri: $uri"
    
    $requestParameters = @{
        Uri = $uri
        Method = $Method
        Headers = @{ "X-Octopus-ApiKey" = $apiKey }
        UseBasicParsing = $true
    }
    
    if ($null -ne $Body) { $requestParameters.Add('Body', ($Body | ConvertTo-Json -Depth 10)) }
    
    return Invoke-WebRequest @requestParameters | % Content | ConvertFrom-Json
}

function Test-SpacesApi {
	Write-Verbose "Checking API compatibility";
	$rootDocument = Invoke-OctopusApi 'api/';
    if($rootDocument.Links -ne $null -and $rootDocument.Links.Spaces -ne $null) {
    	Write-Verbose "Spaces API found"
    	return $true;
    }
    Write-Verbose "Pre-spaces API found"
    return $false;
}

if([string]::IsNullOrWhiteSpace($spaceId)) {
	if(Test-SpacesApi) {
      	$spaceId = $OctopusParameters['Octopus.Space.Id'];
      	if([string]::IsNullOrWhiteSpace($spaceId)) {
          	throw "This step needs to be run in a context that provides a value for the 'Octopus.Space.Id' system variable. In this case, we received a blank value, which isn't expected - please reach out to our support team at https://help.octopus.com if you encounter this error or try providing the Space Id parameter.";
      	}
	}
}

$apiPrefix = "api/"
$tenantUrlBase = @($octopusBaseUrl, 'app#')

if ($spaceId) {
	Write-Host "Using Space $spaceId"
	$apiPrefix += $spaceId
    $tenantUrlBase += $spaceId
}

$body = @{
	Id = $null
    Name = $tenantName
    TenantTags = @($tenantTags)
    ProjectEnvironments = $projectEnvironments
}

Write-Host "Creating tenant $tenantName"
$tenant = Invoke-OctopusApi "$apiPrefix/tenants" -Method Post -Body $body
$tenantUrl = ($tenantUrlBase + "tenants" + $tenant.Id + "overview") -join '/'

Write-Highlight "New tenant [$tenantName]($tenantUrl) has been created."