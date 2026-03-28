$step  = $OctopusParameters['ris_UnpackageStep']
$force = $OctopusParameters['ris_ForceReinstall']
$name  = $OctopusParameters['ris_ServiceName']
$port  = $OctopusParameters['ris_Port']

$outputPath = $OctopusParameters["Octopus.Action[$step].Package.CustomInstallationDirectory"]
if(!$outputPath) 
{
    $outputPath = $OctopusParameters["Octopus.Action[$step].Output.Package.InstallationDirectoryPath"]
}
if(!$outputPath) 
{
    Throw "Unable to find output path for step $step. Make sure you've selected the correct step for your package."
}

$path   = Join-Path $outputPath '\tools\redis-server.exe'
if (-not (Test-Path $path) )
{
    Throw "$path was not found"
}

$service = Get-Service -Name $name -ErrorAction SilentlyContinue
if ($service) {

    if (-not $force) {
        Write-Host "Service already installed. Skipping this time."
        return
    }

    Write-Host ">>> Uninstalling with: sc.exe"
    if ($service.Status -eq 'Running') {
        &"sc.exe" stop $name | Write-Host
    }
    &"sc.exe" delete $name | Write-Host

    $limit = 15
    while (Get-Service -Name $name -ErrorAction SilentlyContinue) {
        Start-Sleep -s 1
        
        $limit = $limit - 1
        if ($limit -eq 0) {
            Throw "Unable to stop Redis service within 15s"
        }
    }
}

Write-Host ">>> Installing with: $path"

Set-Location $outputPath

& $path --service-install --service-name $name --port $port | echo
& $path --service-start   --service-name $name              | echo

Write-Host ">>> Verification: Expecting the service with 'Running' status"

$limit = 15
do {
    Start-Sleep -s 1

    $limit = $limit - 1
    if ($limit -eq 0) {
        Throw "Redis service did not start within 15s"
    }

    $service = Get-Service -Name $name -ErrorAction SilentlyContinue

} until ($service -and $service.Status -eq 'Running')