$resourceGroupName = $OctopusParameters["DeleteResourceGroup.ResourceGroup.Name"]
$resourceGroupLocationAbbr = $OctopusParameters["DeleteResourceGroup.ResourceGroup.Location.Abbr"]

$existingResourceGroups = (az group list --query "[?location=='$resourceGroupLocationAbbr']") | ConvertFrom-JSON

$deleteResourceGroup = $false
foreach ($resourceGroupFound in $existingResourceGroups)
{	
	Write-Host "Checking if current resource group $($resourceGroupFound.name) matches $resourceGroupName"
    if ($resourceGroupFound.name -eq $resourceGroupName)
    {
    	$deleteResourceGroup = $true
    	Write-Highlight "Resource group found, deleting"
    	break
    }
}

if ($deleteResourceGroup)
{
	Write-Host "Deleting the $resourceGroupName because it was found"
	az group delete -n $resourceGroupName -y
}