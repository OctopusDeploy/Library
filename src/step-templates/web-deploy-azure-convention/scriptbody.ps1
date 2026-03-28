[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Deployment")
# A collection of functions that can be used by script steps to determine where packages installed
# by previous steps are located on the filesystem.
 
function Find-InstallLocations {
    $result = @()
    $OctopusParameters.Keys | foreach {
        if ($_.EndsWith('].Output.Package.InstallationDirectoryPath')) {
            $result += $OctopusParameters[$_]
        }
    }
    return $result
}
 
function Find-InstallLocation($stepName) {
    $result = $OctopusParameters.Keys | where {
        $_.Equals("Octopus.Action[$stepName].Output.Package.InstallationDirectoryPath",  [System.StringComparison]::OrdinalIgnoreCase)
    } | select -first 1
 
    if ($result) {
        return $OctopusParameters[$result]
    }
 
    throw "No install location found for step: $stepName"
}
 
function Find-SingleInstallLocation {
    $all = @(Find-InstallLocations)
    if ($all.Length -eq 1) {
        return $all[0]
    }
    if ($all.Length -eq 0) {
        throw "No package steps found"
    }
    throw "Multiple package steps have run; please specify a single step"
}

function Test-LastExit($cmd) {
    if ($LastExitCode -ne 0) {
        Write-Host "##octopus[stderr-error]"
        write-error "$cmd failed with exit code: $LastExitCode"
    }
}

# Somehow we can only check for exactly 'True'
$isStagingText = $OctopusParameters['IsStaging'];
$isStaging = $isStagingText -eq "True"

Write-Host "Is staging text: $isStagingText"
Write-Host "Is staging: $isStaging"

$stepName = $OctopusParameters['WebDeployPackageStepName']
if ([string]::IsNullOrEmpty($stepName)) {
	Write-Host "Defaulting to step name Extract package"
	$stepName = "Extract package"
}

if ($isStaging) {
	$stepName = $stepName + " - staging"
}

$stepPath = ""
if (-not [string]::IsNullOrEmpty($stepName)) {
    Write-Host "Finding path to package step: $stepName"
    $stepPath = Find-InstallLocation $stepName
} else {
    $stepPath = Find-SingleInstallLocation
}
Write-Host "Package was installed to: $stepPath"

Write-Host "##octopus[stderr-progress]"
 
Write-Host "Publishing Website"

$prefix = $OctopusParameters['Prefix']
if ([string]::IsNullOrEmpty($prefix)) {
	Write-Host "Prefix is empty, reading prefix from variable set using AzurePrefix"
	$prefix = $OctopusParameters['AzurePrefix']
}

$websiteName = $OctopusParameters['WebsiteName']
if ([string]::IsNullOrEmpty($websiteName)) {
	Write-Host "WebsiteName is empty, reading website name from variable set using AzureName"
	$websiteName = $OctopusParameters['AzureName']
}

$regionName = $OctopusParameters['RegionName']

$publishUrl = "$prefix-$websiteName-$regionName"
if ($isStaging) {
	$publishUrl = $publishUrl + "-staging"
}
$publishUrl = $publishUrl + ".scm.azurewebsites.net:443"

$userName = '$' + "$prefix-$websiteName-$regionName"
if ($isStaging) {
	$userName = $userName + "__staging"
}

$passwordKey = "AzurePassword-$regionName"
if ($isStaging) {
	$passwordKey = $passwordKey + "-staging"
}

Write-Host "Using the following values to publish:"
Write-Host " * Publish url: $publishUrl"
Write-Host " * Website name: $websiteName"
Write-Host " * User name: $userName"
Write-Host " * Password variable: $passwordKey"

$destBaseOptions = new-object Microsoft.Web.Deployment.DeploymentBaseOptions
$destBaseOptions.UserName = $userName
$destBaseOptions.Password =  $OctopusParameters[$passwordKey]
$destBaseOptions.ComputerName = "https://$publishUrl/msdeploy.axd?site=$websiteName"
$destBaseOptions.AuthenticationType = "Basic"

$syncOptions = new-object Microsoft.Web.Deployment.DeploymentSyncOptions
#$syncOptions.WhatIf = $false
$syncOptions.UseChecksum = $true

$deploymentObject = [Microsoft.Web.Deployment.DeploymentManager]::CreateObject("contentPath", $stepPath)
$deploymentObject.SyncTo("contentPath", $websiteName, $destBaseOptions, $syncOptions)