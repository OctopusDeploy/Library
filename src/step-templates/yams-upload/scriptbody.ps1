$yamsUploaderInstallationParameter = "Octopus.Action[$YamsUploaderStep].Output.Package.InstallationDirectoryPath"
Write-Host "Yams Uploader installation path parameter: $yamsUploaderInstallationParameter" 
$applicationInstallationParameter = "Octopus.Action[$PackageStep].Output.Package.InstallationDirectoryPath"
Write-Host "Application Package installation path parameter: $applicationInstallationParameter" 

$yamsUploader = $OctopusParameters[$yamsUploaderInstallationParameter] + "\content\YamsUploader.exe"
Write-Host "Running Yams Uploader: $yamsUploader" 

$binaries = $OctopusParameters[$applicationInstallationParameter]
Write-Host "Uploading application: $binaries"

& "$yamsUploader" -YamsStorage "$Storage" -ClusterId "$ClusterId" -BinariesPath "$binaries" -AppVersion "$AppVersion" -AppId "$AppId"