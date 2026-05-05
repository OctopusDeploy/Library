try {az --version}
catch
{
    throw "az CLI not installed"
}

$webAppName = $OctopusParameters["azWebApp.WebAppName"]
$resourceGroup = $OctopusParameters["azWebApp.ResourceGroup"]
$restartDelay = $OctopusParameters["azWebApp.RestartDelay"]



Write-Host "Web App Name: $webAppName"
Write-Host "Resource Group: $resourceGroup"
Write-Host "Restart Delay: $restartDelay"

Write-Host "Checking $webAppName status in resource group $resourceGroup"

$appState = az webapp list --resource-group $resourceGroup --query "[?name=='$webAppName'].{state: state, hostName: defaultHostName}" | ConvertFrom-Json

# only execute if running
if($appState.state -eq "running")
{
    $appInstances = az webapp list-instances -n $webAppName --resource-group $resourceGroup --query '[].{Id: id}' | ConvertFrom-Json
    Write-Host "" $appInstances.Count "Instance(s) found`r`n" -ForegroundColor Green

    if($appInstances.count -gt 0){
        foreach ($instance in $appInstances){
            Write-Host "Restarting Instance: $instance"
            az webapp restart --ids $instance.Id
            Write-Host "Pausing $restartDelay second(s)`r`n" -ForegroundColor Yellow
            Start-Sleep -Seconds $restartDelay
        }
    }
}
