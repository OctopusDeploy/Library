$step = $OctopusParameters['Unpackage step']
$previous = $OctopusParameters["Octopus.Action[$step].Package.CustomInstallationDirectory"]
$customExeFilename = $OctopusParameters['Exe filename'];

if(!$previous -or (-not (Test-Path $previous)) )
{
    Write-Host "No installation found in: $previous"
	
    $previous = $OctopusParameters["Octopus.Action[$step].Output.Package.InstallationDirectoryPath"]
    if(!$previous -or (-not (Test-Path $previous)) )
    {
        Write-Host "No installation found in: $previous"
        Break
    }
}


$defaultExeFilename = $OctopusParameters["Octopus.Action[$step].Package.NuGetPackageId"] + ".exe"
$exeFilename = If ($customExeFilename) {$customExeFilename} Else {$defaultExeFilename}
$path = Join-Path $previous $exeFilename

Write-Host "Previous installation: $path"

Start-Process $path -ArgumentList "stop" -NoNewWindow -Wait | Write-Host
Start-Process $path -ArgumentList "uninstall" -NoNewWindow -Wait | Write-Host
