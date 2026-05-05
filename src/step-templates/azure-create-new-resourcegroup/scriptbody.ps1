$ResourceGroupName =$OctopusParameters["CreateResourceGroup.ResourceGroupName"]
$Location =$OctopusParameters["CreateResourceGroup.Location"]
 
 Write-Output "Variables:"
 Write-Output "ResourceGroupName: $ResourceGroupName"
 Write-Output "Location: $Location"

Write-Output '###############################################'
Write-Output '##Step1: Create Resource Group '
$AzureResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if ( $null -eq $AzureResourceGroup)
{
Write-Output "Resource Group $ResourceGroupName does not exist, creating one ..."
$AzureResourceGroup =New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
} 
else{
Write-Output "Resource Group $ResourceGroupName already exists ..."
}

Write-Output '###############################################'
Write-Output '##Step2: Validate Resource Group '

if ($null -eq $AzureResourceGroup ){
Throw "Failed to create resource group $AzureResourceGroupName"
}
