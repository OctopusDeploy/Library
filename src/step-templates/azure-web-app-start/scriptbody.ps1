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

if($appState.state -eq 'running')
{
	Write-Host "Web App $webApp already running"
    return 
}

Write-Host "Starting web app $webApp in resource group $resourceGroup"
az webapp start --name $webApp --resource-group $resourceGroup

Start-Sleep -s 5

$appState = az webapp list --resource-group $resourceGroup --query "[?name=='$webApp'].{state: state, hostName: defaultHostName}" | ConvertFrom-Json

if($appState.state -ne "running")
{
	Throw "Webapp failed to start.  Check the app's activity/error log"
}
