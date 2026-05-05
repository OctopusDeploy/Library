$resourceGroupName = $OctopusParameters["DeleteResourceGroup.ResourceGroup.Name"]
$resourceGroupLocation = $OctopusParameters["DeleteResourceGroup.ResourceGroup.Location"]

$deleteResourceGroup = $false
Try {
	Write-Host "Getting list of existing resource groups"
	$resourceGroupList = Get-AzureRmResourceGroup -Location "$resourceGroupLocation"    
    
    Write-Host "Looping through resource group list"
    foreach ($resourceGroupItem in $resourceGroupList)
    {
    	Write-Host "Checking if current resource group $($resourceGroupItem.ResourceGroupName) matches $resourceGroupName"
    	if ($resourceGroupItem.ResourceGroupName -eq $resourceGroupName)
        {
    		$deleteResourceGroup = $true
            Write-Highlight "Found resource group to delete"
            break
        }
    }
    
} Catch {
	$deleteResourceGroup = $true
}

if ($deleteResourceGroup -eq $true){
	Write-Host "Resource group exists, deleting it"
    Remove-AzureRMResourceGroup -Name $resourceGroupName -Force	
}


