$resourceGroupName = $OctopusParameters["CreateResourceGroup.ResourceGroup.Name"]
$resourceGroupLocationAbbr = $OctopusParameters["CreateResourceGroup.ResourceGroup.Location.Abbr"]

$existingResourceGroups = (az group list --query "[?location=='$resourceGroupLocationAbbr']") | ConvertFrom-JSON

$createResourceGroup = $true
foreach ($resourceGroupFound in $existingResourceGroups)
{	
	Write-Host "Checking if current resource group $($resourceGroupFound.name) matches $resourceGroupName"
    if ($resourceGroupFound.name -eq $resourceGroupName)
    {
    	$createResourceGroup = $false
    	Write-Highlight "Resource group already exists, skipping creation"
    	break
    }
}

if ($createResourceGroup)
{
	Write-Host "Creating the $resourceGroupName because it was not found in $resourceGroupLocationAbbr"
	az group create -l $resourceGroupLocationAbbr -n $resourceGroupName
}