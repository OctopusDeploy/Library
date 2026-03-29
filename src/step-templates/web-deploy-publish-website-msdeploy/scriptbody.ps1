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

$stepName = $OctopusParameters['WebDeployPackageStepName']

$stepPath = ""
if (-not [string]::IsNullOrEmpty($stepName)) {
    Write-Host "Finding path to package step: $stepName"
    $stepPath = Find-InstallLocation $stepName
} else {
    $stepPath = Find-SingleInstallLocation
}
Write-Host "Package was installed to: $stepPath"

Write-Host "##octopus[stderr-progress]"
 
$websiteName = $OctopusParameters['WebsiteName']
$publishUrl = $OctopusParameters['PublishUrl']

$destBaseOptions = new-object Microsoft.Web.Deployment.DeploymentBaseOptions
$destBaseOptions.UserName = $OctopusParameters['Username']
$destBaseOptions.Password = $OctopusParameters['Password']
$destBaseOptions.ComputerName = "https://$publishUrl/msdeploy.axd?site=$websiteName"
$destBaseOptions.AuthenticationType = "Basic"

$syncOptions = new-object Microsoft.Web.Deployment.DeploymentSyncOptions
$syncOptions.WhatIf = $false
$syncOptions.UseChecksum = $true

$enableAppOfflineRule = $OctopusParameters['EnableAppOfflineRule']
if($enableAppOfflineRule -eq $true)
{
    $appOfflineRule = $null
    $availableRules = [Microsoft.Web.Deployment.DeploymentSyncOptions]::GetAvailableRules()
    if (!$availableRules.TryGetValue('AppOffline', [ref]$appOfflineRule))
    {
        throw "Failed to find AppOffline Rule"
    }
    else
    {
        $syncOptions.Rules.Add($appOfflineRule)
        Write-Host "Enabled AppOffline Rule"
    }
}

$preserveAppData = [boolean]::Parse($OctopusParameters['PreserveApp_Data'])

if ($preserveAppData -eq $true) {
    
    Write-Host "Skipping delete actions on App_Data"
    $skipAppDataFiles = new-object Microsoft.Web.Deployment.DeploymentSkipRule("appDataFiles", "Delete", "filePath", "\App_Data\.*", $null)
    $skipAppDataDirectories = new-object Microsoft.Web.Deployment.DeploymentSkipRule("appDataDirectories", "Delete", "dirPath", "\App_Data(\.*|$)", $null)

    $syncOptions.Rules.Add($skipAppDataFiles);
    $syncOptions.Rules.Add($skipAppDataDirectories);
}

$SkipSyncPaths = $OctopusParameters['SkipSyncPaths']
if ([string]::IsNullOrEmpty($SkipSyncPaths) -eq $false)
{
    $skipPaths = $SkipSyncPaths.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach($item in $skipPaths) {
        $index = $skipPaths.IndexOf($item)
        Write-Host "Skipping sync of AbsolutePath: $item."
        $name = "SkipDirective$index"
        $value = "absolutePath=$item"
        $skipDirective = new-object Microsoft.Web.Deployment.DeploymentSkipDirective($name, $value)
        $destBaseOptions.SkipDirectives.Add($skipDirective)
    }
}

if ($OctopusParameters['AllowUntrustedCertificate'] -eq $true) {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true; }
}

Write-Host "Publishing Website"
$deploymentObject = [Microsoft.Web.Deployment.DeploymentManager]::CreateObject("contentPath", $stepPath)

$changes = $deploymentObject.SyncTo("contentPath", $websiteName, $destBaseOptions, $syncOptions)

#Write out all the changes.
$changes | Select-Object -Property *