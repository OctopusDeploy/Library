$ErrorActionPreference = "Stop";
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$AzWebAppName = $OctopusParameters["AzWebApp.DisableAppOffline.AzWebAppName"]
$Filename = $OctopusParameters["AzWebApp.DisableAppOffline.Filename"]
$DeployUsername = $OctopusParameters["AzWebApp.DisableAppOffline.Deployment.Username"]
$DeployPassword = $OctopusParameters["AzWebApp.DisableAppOffline.Deployment.Password"]
$DeploymentUrl = $OctopusParameters["AzWebApp.DisableAppOffline.Deployment.KuduRestApiUrl"]

# Validation
if ([string]::IsNullOrWhiteSpace($AzWebAppName)) {
    throw "Required parameter AzWebApp.DisableAppOffline.AzWebAppName not specified"
}

if ([string]::IsNullOrWhiteSpace($Filename)) {
    throw "Required parameter AzWebApp.DisableAppOffline.Filename not specified"
}
if ([string]::IsNullOrWhiteSpace($DeployUsername)) {
    throw "Required parameter AzWebApp.DisableAppOffline.Deployment.Username not specified"
}
if ([string]::IsNullOrWhiteSpace($DeployPassword)) {
    throw "Required parameter AzWebApp.DisableAppOffline.Deployment.Password not specified"
}
if ([string]::IsNullOrWhiteSpace($DeploymentUrl)) {
    throw "Required parameter AzWebApp.DisableAppOffline.Deployment.KuduRestApiUrl not specified"
}

$DeploymentUrl = $DeploymentUrl.TrimEnd('/')

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

Write-Verbose "AzWebApp.DisableAppOffline.AzWebAppName: $AzWebAppName"
Write-Verbose "AzWebApp.DisableAppOffline.Filename: $FileName"
Write-Verbose "AzWebApp.DisableAppOffline.Deployment.Username: $DeployUsername"
Write-Verbose "AzWebApp.DisableAppOffline.Deployment.Password: ********"
Write-Verbose "AzWebApp.DisableAppOffline.Deployment.KuduRestApiUrl: $DeploymentUrl"

Write-Verbose "Step Name: $StepName"

try {
    $credPair = "$($DeployUsername):$($DeployPassword)"
    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
    $headers = @{ 
        Authorization = "Basic $encodedCredentials"
        # Ignore E-Tag
        "If-Match"    = "*" 
    }

    $filePathUri = "$DeploymentUrl/site/wwwroot/$filename"
    Write-Host "Invoking Delete request for '$filePathUri'"
    $response = Invoke-RestMethod -Method Delete -Uri $filePathUri -Headers $headers

    Write-Verbose "Response: $response"
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $ErrorDetails = $_.ErrorDetails.Message
    $Message = "An error occurred invoking the Azure Web App REST API: $ExceptionMessage"
    if (![string]::IsNullOrWhiteSpace($ErrorDetails)) {
        $Message += "`nDetail: $ErrorDetails"
    }

    Write-Error $Message -Category ConnectionError
}