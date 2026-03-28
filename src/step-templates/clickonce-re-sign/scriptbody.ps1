$xml = [xml](Get-Content "$baseDeployPath\$AppName.application")
$manifestpath = $xml.assembly.dependency.dependentAssembly.codebase
$ApplicationWithVersion = $manifestpath.Split('\\')[1]

#Manifest Resign
& "C:\Program Files (x86)\Microsoft SDKs\Windows\v8.0A\bin\NETFX 4.0 Tools\mage.exe" -Update "$baseDeployPath\$manifestpath" -FromDirectory "$baseDeployPath\Application Files\$ApplicationWithVersion"
& "C:\Program Files (x86)\Microsoft SDKs\Windows\v8.0A\bin\NETFX 4.0 Tools\mage.exe" -Sign "$baseDeployPath\$manifestpath" -CertFile $signcertpath -Password $signCertPass

#Application Resign
& "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\mage.exe" -Update "$baseDeployPath\$AppName.application" -AppManifest "$baseDeployPath\$manifestpath"
& "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\mage.exe" -Sign "$baseDeployPath\$AppName.application" -CertFile $signcertpath -Password $signCertPass

#Rename files back to the .deploy extension, skipping the files that shouldn't be renamed
Get-ChildItem -Path "$baseDeployPath\Application Files\*"  -Recurse | Where-Object {!$_.PSIsContainer -and $_.Name -notlike "*.manifest" -and $_.Name -notlike "*.vsto"} | Rename-Item -NewName {$_.Name + ".deploy"} 