try
{
	az --version
}

catch
{
	throw "az cli not installed"
}

$webApp = $OctopusParameters["Octopus.Action.Azure.WebAppName"]
$resourceGroup = $OctopusParameters["Octopus.Action.Azure.ResourceGroupName"]

$appState = az webapp list --resource-group $resourceGroup --query "[?name=='$webApp'].{state: state, hostName: defaultHostName}" | ConvertFrom-Json

if($appState.state -eq 'stopped')
{
	Write-Host "Web App $webApp already stopped"
    return
}

Write-Host "Stopping webapp $webApp in group $resourceGroup"
az webapp stop --name $webApp --resource-group $resourceGroup
