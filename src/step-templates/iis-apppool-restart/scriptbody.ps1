# Load IIS module:
Import-Module WebAdministration

# Get AppPool Name
$appPoolName = $OctopusParameters['appPoolName']

# Check if exists
if (Test-Path IIS:\AppPools\$appPoolName){
    # Start App Pool if stopped else restart
if ((Get-WebAppPoolState($appPoolName)).Value -eq "Stopped"){
    Write-Output "Starting IIS app pool $appPoolName"
    Start-WebAppPool $appPoolName
}
else {
    Write-Output "Restarting IIS app pool $appPoolName"
    Restart-WebAppPool $appPoolName
}
}
