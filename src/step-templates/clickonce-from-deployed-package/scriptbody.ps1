Write-Host "Building clickonce application ..."

function Validate-Parameter([REF]$f, $name, $value) {
    if (!$value) {
        throw ('Missing required value for parameter ''{0}''.' -f $name)
    }
    
    $f.Value = $value
    Write-Host "Parameters [$name] has been initialized with : [$value]"
}

### Parameters
$deployStepName = $null
$appName = $null
$exeFileName = $null
$destinationPath = $null
$certFilePath = $null
$certPassword = $null
$publisher = $null
$mageExe = $null
$version = $null
$binariesFolderPath = $null
$coAppName = $null
$iconFile = $null

Validate-Parameter ([REF]$deployStepName) 'Deploy step name to read binaries from' $OctopusParameters['DeployStepName']
Validate-Parameter ([REF]$appName) 'Project name' $OctopusParameters['Octopus.Project.Name']
Validate-Parameter ([REF]$coAppName) 'Application display name' $OctopusParameters['DisplayName']

Validate-Parameter ([REF]$exeFileName) 'Executable file name' $OctopusParameters['ExeFileName']
Validate-Parameter ([REF]$destinationPath) 'Path to the directory where to deploy the ClickOnce package' $OctopusParameters['DestinationPath']
Validate-Parameter ([REF]$certFilePath) 'Path to the certification file' $OctopusParameters['SignCertFilePath']
Validate-Parameter ([REF]$certPassword) 'Password of the certification file' $OctopusParameters['SignCertPassword']
Validate-Parameter ([REF]$publisher) 'Publisher name' $OctopusParameters['Publisher']
Validate-Parameter ([REF]$mageExe) 'Path to the mage.exe' $OctopusParameters['MageExePath']
Validate-Parameter ([REF]$iconFile) 'Icon file' $OctopusParameters['IconFile']

### end of parameters

Validate-Parameter ([REF]$version) 'Version number (from release)' $OctopusParameters['Octopus.Release.Number']

$binariesFolderParameter = -join("Octopus.Action[",$deployStepName,"].Output.Package.InstallationDirectoryPath")
Write-Host "Trying to get Installation folder parameter value for : [$binariesFolderParameter]"

$binariesFolderPath = $OctopusParameters[$binariesFolderParameter]
if(!$binariesFolderPath){
     throw ('Unable to retrieve binaries path from previous step execution for step with name ''{0}''.' -f $deployStepName)
}

$appVersionAndNumber = -join($appName, "_", $version)
$packageDestinationSubDirectory = -join ("Application_Files/", $appVersionAndNumber)
$packageDestinationPath = -join ($destinationPath, "/", $packageDestinationSubDirectory) 
$appManifestRelativePath = -join ("Application_Files/",$appVersionAndNumber, "/", $exeFileName, ".manifest")
$appManifestFilePath = -join ($binariesFolderPath, "/", $exeFileName, ".manifest")

$coAppFilePath = -join($binariesFolderPath, "\", $appName, ".application")
$coAppFilePathServer = -join($destinationPath, "\", $appName, ".application")

### Create Application manifest
Write-Host "Creating application manifest at "$appManifestFilePath
& $mageExe -New Application -t "$appManifestFilePath" -n "$coAppName" -v $version -p msil -fd "$binariesFolderPath" -tr FullTrust -a sha256RSA -if $iconFile
Write-Host "Signing application manifest ..."
& $mageExe -Sign "$appManifestFilePath" -cf $certFilePath -pwd $certPassword

### Create Deployment application
Write-Host "Creating CO application [$coAppName] at "$coAppFilePath
& $mageExe -New Deployment -t "$coAppFilePath" -n "$coAppName" -v $version -p msil -appm $appManifestFilePath -ip true -i true -um true -pub $publisher -pu "$coAppFilePathServer" -appc $appManifestRelativePath -a sha256RSA

Write-Host "Updating minimum version to force auto-update"
& $mageExe -Update $coAppFilePath -mv $version -pub $publisher -a sha256RSA

Write-Host "Changing expiration max age => before application startup (hacking xml) of "$coAppFilePath
$content = Get-Content $coAppFilePath
$content -replace "<expiration maximumAge=`"0`" unit=`"days`" />", "<beforeApplicationStartup />" | set-content $coAppFilePath

Write-Host "Signing CO application [$coAppName] ..."
& $mageExe -Sign "$coAppFilePath" -cf $certFilePath -pwd $certPassword


Write-Host "Copying binaries from "$binariesFolderPath
Write-Host "to destination "$packageDestinationPath

### Remove any existing files from the package destination folder
Remove-Item $packageDestinationPath -Recurse -ErrorAction SilentlyContinue

### Ensure target directory exists in order not to fail the copy
New-Item $packageDestinationPath -ItemType directory > $null

### Copy binaries to destination folder
Copy-Item $binariesFolderPath"/*" $packageDestinationPath -recurse -Force > $null
Copy-Item $coAppFilePath $destinationPath -Force > $null

Write-Host "Building clickonce application script completed."
