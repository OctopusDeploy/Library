#region Verify variables

#Verify rsflbAzureSubscription is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['rsflbAzureSubscription']))
{
  Throw 'Azure Subscription cannot be null.'
}
$azureSubscription = $OctopusParameters['rsflbAzureSubscription']
Write-Host ('Azure Subscription: ' + $azureSubscription)

#Verify rsflbAzureResourceGroup is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['rsflbAzureResourceGroup']))
{
  Throw 'Azure Resource Group cannot be null.'
}
$azureResourceGroup = $OctopusParameters['rsflbAzureResourceGroup']
Write-Host ('Azure Resource Group: ' + $azureResourceGroup)

#Verify rsflbAzureMachineName is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['rsflbAzureMachineName']))
{
  Throw 'Azure Machine Name cannot be null.'
}
$azureMachineName = $OctopusParameters['rsflbAzureMachineName']
Write-Host ('Azure Machine Name: ' + $azureMachineName)

#endregion

#region Process

Set-AzureRmContext -SubscriptionName $azureSubscription

$azureVM = Get-AzureRmVM -ResourceGroupName $azureResourceGroup -Name $azureMachineName
If (!$azureVM)
{
  Throw 'Could not retrieve server from Azure needed to remove from Load Balancer.'
}

$nic = (Get-AzureRmNetworkInterface -ResourceGroupName $azureResourceGroup | Where-Object {$_.VirtualMachine.Id -eq $azureVM.Id})
If (!$nic)
{
  Throw 'Could not retrieve NIC from Azure needed to remove from Load Balancer.'
}

$nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $null
$nic | Set-AzureRmNetworkInterface

#endregion