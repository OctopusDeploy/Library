$creds = Invoke-AzureRmResourceAction -ResourceGroupName $ResourceGroup -ResourceType Microsoft.Web/sites/config `
            -ResourceName $WebApp/publishingCredentials -Action list -ApiVersion 2015-08-01 -Force

Set-OctopusVariable -name "PublishingUsername" -value $creds.Properties.PublishingUsername
Set-OctopusVariable -name "PublishingPassword" -value $creds.Properties.PublishingPassword