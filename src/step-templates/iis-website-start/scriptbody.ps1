# Load IIS module:
Import-Module WebAdministration

# Set a name of the site we want to start
$webSiteName = $OctopusParameters['webSiteName']

# Get web site object
try {
$webSite = Get-Item "IIS:\Sites\$webSiteName"
}
Catch [System.IO.FileNotFoundException]{
	# Some OS bug out if Default Web Site is deleted.
# So we need to call this 2 times.
$webSite = Get-Item "IIS:\Sites\$webSiteName"
}

Write-Output "Starting IIS web site $webSiteName"
$webSite.Start()
