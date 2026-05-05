[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")

function Expand-ZIPFile($file, $destination)
{
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    foreach($item in $zip.items())
    {
        $shell.Namespace($destination).copyhere($item)
    }
}

$TempFolder = "\TempNupkg"
$ExpandedFolder = "\expanded"

$FileDestinationPath = $RegisteringDllFolderPath + "\" + $DllName 
$FileSourcePath = $RegisteringDllFolderPath + $TempFolder + $ExpandedFolder + $DllPathInExpanded + "\" + $DllName

$TempPath = $RegisteringDllFolderPath + $TempFolder
$NupkgPath = $RegisteringDllFolderPath + $TempFolder + "\temp.zip"
$ExpandedTempPath = $RegisteringDllFolderPath + $TempFolder + $ExpandedFolder

$DllUrl = "https://www.nuget.org/api/v2/package/"+ $PackageName +"/" + $PackageVersion

if (!(Test-Path $ExpandedTempPath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $ExpandedTempPath
}

Write-Host "Allow SecurityProtocol TLS, TLS 1.1 and TLS 1.2 ..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
Write-Host "Dowloading package ..."
Invoke-WebRequest -Uri $DllUrl -OutFile $NupkgPath

Write-Host "Expanding Archive ..."
Expand-ZIPFile –File $NupkgPath –Destination $ExpandedTempPath

Write-Host "Copying to destination folder ..."
Copy-Item $FileSourcePath -Destination $FileDestinationPath

Remove-Item -Recurse -Force $TempPath
Write-Host "Deleteing temp folders ..."

Write-Host "Library Found"

#Note that you should be running PowerShell as an Administrator
Write-Host "Installing to GAC ..."
$publish = New-Object System.EnterpriseServices.Internal.Publish
$publish.GacInstall($fileDestinationPath)
Write-Host "Installed to GAC"