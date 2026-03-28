

<#
 ----- Octopus - Import Certificate ----- 
    Paul Marston @paulmarsy (paul@marston.me)
Links
    https://github.com/OctopusDeploy/Library/commits/master/step-templates/octopus-import-certificate.json
#>

$securityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = $securityProtocol

$ErrorActionPreference = 'Stop'

$StepTemplate_BaseUrl = $StepTemplate_OctopusUrl.Trim('/')

if ([string]::IsNullOrWhiteSpace($StepTemplate_ApiKey)) {
    throw "The step parameter 'API Key' was not found. This step requires an API Key to function, please provide one and try again."
}
filter Out-Verbose {
    Write-Verbose ($_ | Out-String)
}
filter Out-Indented {
    $_ | Out-String | % Trim | % Split "`n" | % { "`t$_" }  
}
function Invoke-OctopusApi {
    param(
        [Parameter(Position = 0, Mandatory)]$Uri,
        [ValidateSet("Get", "Post")]$Method = 'Get',
        $Body
    )
    $requestParameters = @{
        Uri = ('{0}/{1}' -f $StepTemplate_BaseUrl, $Uri.TrimStart('/'))
        Method = $Method
        Headers = @{ "X-Octopus-ApiKey" = $StepTemplate_ApiKey }
        UseBasicParsing = $true
    }
    Write-Verbose "$($Method.ToUpperInvariant()) $($requestParameters.Uri)"   
    if ($null -ne $Body) { $requestParameters.Add('Body', ($Body | ConvertTo-Json -Depth 10)) }
    try {
        Invoke-WebRequest @requestParameters | % Content | ConvertFrom-Json | Write-Output
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $errorResponse = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()).ReadToEnd()
            throw ("$($_.Exception.Message)`n{0}" -f $errorResponse)
        }
        
        if ($_.Exception.Message) {
        	$message = $_.Exception.Message
        	Write-Highlight $message
            throw "$message"
        }
    }
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

function Get-OctopusItems
{
	# Define parameters
    param(
    	$OctopusUri,
        $ApiKey,
        $SkipCount = 0
    )
    
    # Define working variables
    $items = @()
    $skipQueryString = ""
    $headers = @{"X-Octopus-ApiKey"="$ApiKey"}

    # Check to see if there there is already a querystring
    if ($octopusUri.Contains("?"))
    {
        $skipQueryString = "&skip="
    }
    else
    {
        $skipQueryString = "?skip="
    }

    $skipQueryString += $SkipCount
    
    # Get intial set
    $resultSet = Invoke-RestMethod -Uri "$($OctopusUri)$skipQueryString" -Method GET -Headers $headers

    # Check to see if it returned an item collection
    if ($resultSet.Items)
    {
        # Store call results
        $items += $resultSet.Items
    
        # Check to see if resultset is bigger than page amount
        if (($resultSet.Items.Count -gt 0) -and ($resultSet.Items.Count -eq $resultSet.ItemsPerPage))
        {
            # Increment skip count
            $SkipCount += $resultSet.ItemsPerPage

            # Recurse
            $items += Get-OctopusItems -OctopusUri $OctopusUri -ApiKey $ApiKey -SkipCount $SkipCount
        }
    }
    else
    {
        return $resultSet
    }
    

    # Return results
    return $items
}

function Get-OctopusIds 
{
	# Define parameters
    param (
    	$OctopusCollection,
        $NamesArray
    )
    
    $returnList = @()
    
    foreach ($item in $NamesArray)
    {
    	# Trim item
        $item = $item.Trim()
        
        # Compare
        $octopusItem = $OctopusCollection | Where-Object {$_.Name -eq $item}
        
        if ($null -ne $octopusItem)
        {
        	# Add to array
            $returnList += $item.Id
        }
    }
    
    # Return list
    return $returnList
}

if(Test-SpacesApi) {
	$spaceId = $OctopusParameters['Octopus.Space.Id'];
    if([string]::IsNullOrWhiteSpace($spaceId)) {
        throw "This step needs to be run in a context that provides a value for the 'Octopus.Space.Id' system variable. In this case, we received a blank value, which isn't expected - please reach out to our support team at https://help.octopus.com if you encounter this error.";
    }
	$baseApiUrl = "/api/$spaceId" ;
} else {
	$baseApiUrl = "/api" ;
}

# Get all environments
Write-Host "Getting list of Environments ...$($StepTemplate_BaseUrl)$($baseApiUrl)/environments"
$environmentList = Get-OctopusItems -OctopusUri "$($StepTemplate_BaseUrl)$($baseApiUrl)/environments" -ApiKey $StepTemplate_ApiKey
$environmentIds = Get-OctopusIds -OctopusCollection $environmentList -NamesArray $StepTemplate_Environments.Split(",")

# Get tenants
Write-Host "Getting list of Tenants ..."
$tenantList = Get-OctopusItems -OctopusUri "$($StepTemplate_BaseUrl)$($baseApiUrl)/tenants" -ApiKey $StepTemplate_ApiKey
$tenantIds = Get-OctopusIds -OctopusCollection $tenantList -NamesArray $StepTemplate_Tenants.Split(",")

# Get tenant tags
Write-Host "Getting list of Tenant Tags ..."
$tenantTagList = Get-OctopusItems -OctopusUri "$($StepTemplate_BaseUrl)$($baseApiUrl)/tagsets" -ApiKey $StepTemplate_ApiKey
$tenantTagIds = Get-OctopusIds -OctopusCollection $tenantTagList -NamesArray $StepTemplate_TenantTags.Split(",")

$certificate = switch ($StepTemplate_CertEncoding) {
    'file' {   
        if (!(Test-Path $StepTemplate_Certificate)) {
            throw "Certificate file $StepTemplate_Certificate does not exist"
        }
        $certificateBytes = Get-Content -Path $StepTemplate_Certificate -Encoding Byte
        [System.Convert]::ToBase64String($certificateBytes)
    }
    'base64' {
        $StepTemplate_Certificate
    }
}

$existingCert = Invoke-OctopusApi "$baseApiUrl/certificates" | % Items | ? Name -eq $StepTemplate_CertificateName
if ($existingCert) {
    Write-Host 'Existing certificate will be archived & replaced...'
    Invoke-OctopusApi ("$baseApiUrl/certificates/{0}/replace" -f $existingCert.Id) -Method Post -Body @{
        certificateData = $certificate
        password = $StepTemplate_Password
    } | % {
        $_.CertificateData = $null
        $_.Password = $null
        $_
    } | Out-Verbose
} else {
    Write-Host 'Creating & importing new certificate...'
    Invoke-OctopusApi "$baseApiUrl/certificates" -Method Post -Body @{
        Name = $StepTemplate_CertificateName
        CertificateData = @{
            HasValue = $true
            NewValue = $certificate
        }
        Password = @{
            HasValue = $true
            NewValue = $StepTemplate_Password
        }
        TenantedDeploymentParticipation = $StepTemplate_TenantParticipation
        EnvironmentIds = $environmentIds
        TenantIds = $tenantIds
        TenantTags = $tenantTagIds
    } | Out-Verbose
}
Write-Host 'Certificate has been imported:'
Invoke-OctopusApi "$baseApiUrl/certificates" | % Items | ? Name -eq $StepTemplate_CertificateName | Out-Indented