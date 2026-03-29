$ErrorActionPreference = "Stop";
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$SourcePackage = "AzWebApp.EnableAppOffline.SourcePackage"
$AzWebAppName = $OctopusParameters["AzWebApp.EnableAppOffline.AzWebAppName"]
$FilePath = $OctopusParameters["AzWebApp.EnableAppOffline.FilePath"]
$Filename = $OctopusParameters["AzWebApp.EnableAppOffline.Filename"]
$DeployUsername = $OctopusParameters["AzWebApp.EnableAppOffline.Deployment.Username"]
$DeployPassword = $OctopusParameters["AzWebApp.EnableAppOffline.Deployment.Password"]
$DeploymentUrl = $OctopusParameters["AzWebApp.EnableAppOffline.Deployment.KuduRestApiUrl"]

# Validation
if ([string]::IsNullOrWhiteSpace($AzWebAppName)) {
    throw "Required parameter AzWebApp.EnableAppOffline.AzWebAppName not specified"
}
if ([string]::IsNullOrWhiteSpace($Filename)) {
    throw "Required parameter AzWebApp.EnableAppOffline.Filename not specified"
}
if ([string]::IsNullOrWhiteSpace($DeployUsername)) {
    throw "Required parameter AzWebApp.EnableAppOffline.Deployment.Username not specified"
}
if ([string]::IsNullOrWhiteSpace($DeployPassword)) {
    throw "Required parameter AzWebApp.EnableAppOffline.Deployment.Password not specified"
}
if ([string]::IsNullOrWhiteSpace($DeploymentUrl)) {
    throw "Required parameter AzWebApp.EnableAppOffline.Deployment.KuduRestApiUrl not specified"
}

$DeploymentUrl = $DeploymentUrl.TrimEnd('/')
$ExtractPathKey = "Octopus.Action.Package[$($SourcePackage)].ExtractedPath"

$ExtractPath = $OctopusParameters[$ExtractPathKey]
$FilePath = Join-Path -Path $ExtractPath -ChildPath $FilePath
if (!(Test-Path $FilePath)) {
    throw "Either the local or package extraction folder $FilePath does not exist or the Octopus Tentacle does not have permission to access it."
}

$sourceFilePath = Join-Path -Path $FilePath -ChildPath $Filename

if (!(Test-Path $sourceFilePath)) {
    throw "The file located at '$sourceFilePath' does not exist or the Octopus Tentacle does not have permission to access it."
}
$destinationFilePathUri = "$DeploymentUrl/site/wwwroot/$filename"

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

Write-Verbose "AzWebApp.EnableAppOffline.AzWebAppName: $AzWebAppName"
Write-Verbose "AzWebApp.EnableAppOffline.FilePath: $FilePath"
Write-Verbose "AzWebApp.EnableAppOffline.Filename: $FileName"
Write-Verbose "AzWebApp.EnableAppOffline.Deployment.Username: $DeployUsername"
Write-Verbose "AzWebApp.EnableAppOffline.Deployment.Password: ********"
Write-Verbose "AzWebApp.EnableAppOffline.Deployment.KuduRestApiUrl: $DeploymentUrl"

Write-Verbose "Step Name: $StepName"

try {
    $credPair = "$($DeployUsername):$($DeployPassword)"
    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
    $headers = @{ 
        Authorization = "Basic $encodedCredentials"
        # Ignore E-Tag
        "If-Match" = "*" 
    }
    
    Write-Host "Invoking Put request for '$sourceFilePath' to '$destinationFilePathUri'"
    $response = Invoke-RestMethod -Method Put -Infile $sourceFilePath -Uri $destinationFilePathUri -Headers $headers -UserAgent 'powershell/1.0' -ContentType 'application/json'
    
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