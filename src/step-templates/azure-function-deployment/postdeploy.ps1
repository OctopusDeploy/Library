$installationPath = $OctopusParameters["Octopus.Action.Package.InstallationDirectoryPath"]
$packageId = $OctopusParameters["Octopus.Action.Package.PackageId"]
$packageVersion = $OctopusParameters["Octopus.Action.Package.PackageVersion"]

Write-Host "Installation Path: $($installationPath)"
Write-Host "Package ID: $($packageId)"
Write-Host "Package Version: $($packageVersion)"

$zipFilePath = "$($installationPath)\$($packageId).$($packageVersion).zip"

Write-Host "Zip File Path: $($zipFilePath)"

Compress-Archive -Path "$($installationPath)\*" -DestinationPath $zipFilePath

Write-Host "Deployment zip file created"

$username = $OctopusParameters["Azf.Username"]
$password = $OctopusParameters["Azf.Password"]
$appName = $OctopusParameters["Azf.ApplicationName"]

if(!$username){
    Write-Error "No Username has been supplied. You can do this from the Step Details page of this step."
    
    exit 1;
}


if(!$password){
    Write-Error "No Password has been supplied. You can do this from the Step Details page of this step."
    
    exit 1;
}


if(!$appName){
    Write-Error "No Application Name has been supplied. You can do this from the Step Details page of this step."
    
    exit 1;
}

$authHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))

$apiUrl = "https://$($appName).scm.azurewebsites.net/api/zipdeploy"

Write-Host "Uploading deployment zip file to $($apiUrl)"

# Set secure protocols
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $authHeader)} -Method POST -InFile $zipFilePath -ContentType "multipart/form-data"

Write-Host "Upload complete"
