# Load IIS module:
Import-Module WebAdministration

# Get AppPool Name
$appPoolName = $OctopusParameters['appPoolName']

Write-Output "Starting IIS app pool $appPoolName"
Start-WebAppPool $appPoolName


