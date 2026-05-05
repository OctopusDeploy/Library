Write-Host "Resource Group Name: $($ResourceGroupName)"
Write-Host "Web App Name: $($WebAppName)"
Write-Host "Slot Name: $($SlotName)"

function Get-AzureRmWebAppPublishingCredentials($ResourceGroupName, $WebAppName, $SlotName = $null){	
	
	if ([string]::IsNullOrWhiteSpace($SlotName)) {
		$resourceType = "Microsoft.Web/sites/config"
		$resourceName = "$WebAppName/publishingcredentials"
	} else {
		$resourceType = "Microsoft.Web/sites/slots/config"
		$resourceName = "$WebAppName/$SlotName/publishingcredentials"
	}

	$publishingCredentials = Invoke-AzureRmResourceAction -ResourceGroupName $ResourceGroupName -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2015-08-01 -Force
    
    return $publishingCredentials

}

function Get-KuduApiAuthorisationHeaderValue($ResourceGroupName, $WebAppName, $SlotName = $null) {

    $publishingCredentials = Get-AzureRmWebAppPublishingCredentials $ResourceGroupName $WebAppName $SlotName

    return ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishingCredentials.Properties.PublishingUserName, $publishingCredentials.Properties.PublishingPassword))))

}

function Delete-PathFromWebApp($ResourceGroupName, $WebAppName, $SlotName = $null, $kuduPath) {
	
    $kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue $ResourceGroupName $WebAppName $SlotName
    
    Write-Host "Kudu Auth Token":
    Write-Host $kuduApiAuthorisationToken
    
    if ([string]::IsNullOrWhiteSpace($SlotName)) {
        $kuduApiUrl = "https://$WebAppName.scm.azurewebsites.net/api/vfs"
    } else {
        $kuduApiUrl = "https://$WebAppName`-$SlotName.scm.azurewebsites.net/api/vfs"
    }
    
    Write-Host "API Url: $($kuduApiUrl)"
    Write-Host "File Path: $($kuduPath)"
    
    Invoke-RestMethod -Uri "$kuduApiUrl/site/wwwroot/$kuduPath" `
                      -Headers @{"Authorization"=$kuduApiAuthorisationToken;"If-Match"="*"} `
                      -Method DELETE 
}

function Delete-FilesAndFoldersFromWebApp($ResourceGroupName, $WebAppName, $SlotName, $FilesList, $RetryAttempts = 3) {

    $list = $FilesList.Split([Environment]::NewLine)

    foreach($item in $list) {
        if(![string]::IsNullOrWhiteSpace($item)) {

            $retryCount = $RetryAttempts
            $retry = $true

            while ($retryCount -gt 0 -and $retry) {
                try {
                    $retryCount = $retryCount -1

                    Delete-PathFromWebApp $ResourceGroupName $WebAppName $SlotName $item

                    $retry = $false
                } catch {
                    $retry = $true
                    if($retryCount -eq 0) {
                        throw ("Exceeded retry attempts " + $RetryAttempts + " for " + $item)
                    }
                }
            }
        }
    }
}

Delete-FilesAndFoldersFromWebApp $ResourceGroupName $WebAppName $SlotName $FilesList $RetryAttempts