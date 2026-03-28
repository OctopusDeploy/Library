$webAppName = $OctopusParameters["Octopus.Action.Azure.WebAppName"]
$rg = $OctopusParameters["Octopus.Action.Azure.ResourceGroupName"]
$slot = $OctopusParameters["Octopus.Action.Azure.DeploymentSlot"]
$isSlotSettings = $OctopusParameters["azureWebAppSettings.isSlotSettings"]

$settingsType = "settings"

$appSettings = $OctopusParameters["azureWebAppSettings.settings"]

$settings = ""

Write-Host "Parsing Settings"

$appSettings -split "`n" | ForEach-Object { $settings += "$_ "}

$settings = $settings.TrimEnd(' ')

$cmdArgs = "--name $webAppName --resource-group $rg"

if(![string]::IsNullOrEmpty($slot))
{
	if($isSlotSettings -eq 'true')
    {
    	$settingsType = "slot-settings"
    }
    
	$settings += " --slot $slot"
}

$settingsArgs = " --$settingsType $settings"

Write-Host "Setting app settings"

$cmd = "az webapp config appsettings set $cmdArgs $settingsArgs"

write-verbose "command to execute: $cmd"

Invoke-Expression $cmd
