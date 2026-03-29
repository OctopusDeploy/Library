try {az --version}
catch
{
    throw "az CLI not installed"
}

$webApp = $OctopusParameters["Octopus.Action.Azure.WebAppName"]
$resourceGroup = $OctopusParameters["Octopus.Action.Azure.ResourceGroupName"]
$startIfStopped = $OctopusParameters["azWebApp.StartIfStopped"]

Write-Host "Checking webapp $webApp status in resource group $resourceGroup"

$appState = az webapp list --resource-group $resourceGroup --query "[?name=='$webApp'].{state: state, hostName: defaultHostName}" | ConvertFrom-Json
if($appState.state -eq "stopped")
{
    if($startIfStopped -eq 'true')
    {
        Write-Host "Webapp is not running. Starting..." -NoNewline
    	az webapp start --name $webApp --resource-group $resourceGroup
        Write-Host "Done"
    }
    else
    {
      Throw "Webapp is not running."
    }
}

Write-Host "Webapp running, restarting"

else
{
	Write-Host "Restarting $webApp in resource group $resourceGroup"
	az webapp restart --name $webApp --resource-group $resourceGroup
}

Start-Sleep -s 5

$appState = az webapp list --resource-group $resourceGroup --query "[?name=='$webApp'].{state: state, hostName: defaultHostName}" | ConvertFrom-Json

if($appState.state -ne "running")
{
	Throw "Webapp failed to start.  Check the app's activity/error log"
}

write-host "Webapp $webApp running. Check at: $($appState.hostName)"
