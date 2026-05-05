$offlineHtml = Join-Path $OctopusParameters["InstallationFolder"] $OctopusParameters["AppOfflineFileName"]
$onlineHtml = Join-Path $OctopusParameters["InstallationFolder"] $OctopusParameters["AppOnlineFileName"]

#If neither file exists, throw a fit
if ($OctopusParameters["ChangeAppOffline.CheckForFile"] -eq $True -and !(Test-Path($offlineHtml)) -and !(Test-Path($onlineHtml)))
{
	Write-Error "Missing both online and offline files!"
    return
}


if ("#{ChangeMode}" -eq "Online")
{
    #Offline exists and so does online - remove offline
    if ((Test-Path($offlineHtml)) -and (Test-Path($onlineHtml)))
    {
        Remove-Item $offlineHtml
    }
    
    #Offline exists and online doesn't - move offline to online
    if ((Test-Path($offlineHtml)) -and !(Test-Path($onlineHtml)))
    {
        Move-Item $offlineHtml $onlineHtml
    }
}

if ("#{ChangeMode}" -eq "Offline")
{
    #Online exists and offline doesn't - move online to offline
    if ((Test-Path($onlineHtml)) -and !(Test-Path($offlineHtml)))
    {
        Move-Item $onlineHtml $offlineHtml
    }
}