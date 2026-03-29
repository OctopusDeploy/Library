$step = $OctopusParameters['Unpackage step']
$username = $OctopusParameters['Username'];
$password = $OctopusParameters['Password'];
$customExeFilename = $OctopusParameters['Exe filename'];

$outputPath = $OctopusParameters["Octopus.Action[$step].Package.CustomInstallationDirectory"]
if(!$outputPath) 
{
    $outputPath = $OctopusParameters["Octopus.Action[$step].Output.Package.InstallationDirectoryPath"]
}

$defaultExeFilename = $OctopusParameters["Octopus.Action[$step].Package.NuGetPackageId"] + ".exe"
$exeFilename = If ($customExeFilename) {$customExeFilename} Else {$defaultExeFilename}
$path = Join-Path $outputPath $exeFilename

if(-not (Test-Path $path) )
{
    Throw "$path was not found"
}

Write-Host "Installing from: $path"
if(!$username)
{
    Start-Process $path -ArgumentList "install" -NoNewWindow -Wait | Write-Host
} 
else 
{
    Start-Process $path -ArgumentList @("install", "-username", $username, "-password", $password) -NoNewWindow -Wait | Write-Host
}
Start-Process $path -ArgumentList "start" -NoNewWindow -Wait | Write-Host
