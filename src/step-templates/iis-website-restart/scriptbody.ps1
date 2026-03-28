# Load IIS module:
Import-Module WebAdministration

# Set a name of the site we want to restart
$webSiteName = $OctopusParameters['webSiteName']

# Get web site object
$webSite = Get-Item "IIS:\Sites\$webSiteName"

Write-Output "Stopping IIS web site $webSiteName"
$webSite.Stop()
Write-Output "Starting IIS web site $webSiteName"
$webSite.Start()
