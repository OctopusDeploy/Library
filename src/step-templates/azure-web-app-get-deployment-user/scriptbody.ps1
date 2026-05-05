$ErrorActionPreference = "Stop";
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$resourceGroupName = $OctopusParameters["AzWebApp.DeploymentCreds.AzResourceGroup"]
$WebAppName = $OctopusParameters["AzWebApp.DeploymentCreds.AzWebAppName"]
$PublishCredentialType = $OctopusParameters["AzWebApp.DeploymentCreds.PublishCredentialType"]
$StepName = $OctopusParameters["Octopus.Step.Name"]

# Validation
if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
    throw "Required parameter AzWebApp.DeploymentCreds.AzResourceGroup not specified"
}
if ([string]::IsNullOrWhiteSpace($WebAppName)) {
    throw "Required parameter AzWebApp.DeploymentCreds.AzWebAppName not specified"
}
if ([string]::IsNullOrWhiteSpace($PublishCredentialType)) {
    throw "Required parameter AzWebApp.DeploymentCreds.PublishCredentialType not specified"
}
    
Write-Verbose "Azure Resource Group Name: $resourceGroupName"
Write-Verbose "Azure Web App Name: $WebAppName"
Write-Verbose "Publish Credential Type: $PublishCredentialType"

Write-Host "Getting $PublishCredentialType publish profile deployment credentials..."

$profiles = az webapp deployment list-publishing-profiles --resource-group $resourceGroupName --name $WebAppName | ConvertFrom-Json | where { $_.publishMethod -ieq $PublishCredentialType } 

Set-OctopusVariable -name "userName" -value $profiles.userName -Sensitive
Write-Highlight "Created output variable: ##{Octopus.Action[$StepName].Output.userName}"
Set-OctopusVariable -name "userPWD" -value $profiles.userPWD -Sensitive
Write-Highlight "Created output variable: ##{Octopus.Action[$StepName].Output.userPWD}"

Write-Host "Output variables generated for deployment credentials!"