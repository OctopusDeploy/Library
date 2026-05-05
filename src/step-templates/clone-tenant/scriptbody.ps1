$securityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = $securityProtocol

$octopusBaseUrl = $CloneTenantStep_OctopusUrl.Trim('/')
$apiKey = $CloneTenantStep_ApiKey
$tenantToClone = $CloneTenantStep_TenantIdToClone
$tenantName = $CloneTenantStep_TenantName
$cloneVariables = $CloneTenantStep_CloneVariables
$cloneTags = $CloneTenantStep_CloneTags
$spaceId = $CloneTenantStep_SpaceId

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($octopusBaseUrl)) {
    throw "The step parameter 'Octopus Base Url' was not found. This step requires the Octopus Server URL to function, please provide one and try again."
}

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "The step parameter 'Octopus API Key' was not found. This step requires an API Key to function, please provide one and try again."
}

if ([string]::IsNullOrWhiteSpace($tenantToClone)) {
    throw "The step parameter 'Id of Tenant to Clone' was not found. Please provide one and try again."
}

if ([string]::IsNullOrWhiteSpace($tenantName)) {
    throw "The step parameter 'New Tenant Name' was not found. Please provide one and try again."
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
	$apiPrefix += $spaceId
    $tenantUrlBase += $spaceId
}

Write-Host "Fetching source tenant"
$tenant = Invoke-OctopusApi "$apiPrefix/tenants/$tenantToClone"

$sourceTenantId = $tenant.Id
$sourceTenantName = $tenant.Name
$tenant.Id = $null
$tenant.Name = $tenantName

if ($cloneTags -ne $true) {
	Write-Host "Clearing tenant tags"
    $tenant.TenantTags = @()
}

Write-Host "Creating new tenant"
$newTenant = Invoke-OctopusApi "$apiPrefix/tenants" -Method Post -Body $tenant

if ($cloneVariables -eq $true) {
	Write-Host "Cloning variables"
    $variables = Invoke-OctopusApi $tenant.Links.Variables
    $variables.TenantId = $newTenant.Id
    $variables.TenantName = $tenantName

    Invoke-OctopusApi $newTenant.Links.Variables -Method Put -Body $variables | Out-Null
}

$tenantUrl = ($tenantUrlBase + "tenants" + $newTenant.Id + "overview") -join '/'
$sourceTenantUrl = ($tenantUrlBase + "tenants" + $sourceTenantId + "overview") -join '/'

Write-Highlight "New tenant [$tenantName]($tenantUrl) has been cloned from [$sourceTenantName]($sourceTenantUrl)"