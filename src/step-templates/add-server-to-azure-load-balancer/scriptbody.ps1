#region Verify variables

#Verify psbilbAzureSubscription is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['psbilbAzureSubscription']))
{
  Throw 'Azure Subscription cannot be null.'
}
$azureSubscription = $OctopusParameters['psbilbAzureSubscription']
Write-Host ('Azure Subscription: ' + $azureSubscription)

#Verify psbilbAzureResourceGroup is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['psbilbAzureResourceGroup']))
{
  Throw 'Azure Resource Group cannot be null.'
}
$azureResourceGroup = $OctopusParameters['psbilbAzureResourceGroup']
Write-Host ('Azure Resource Group: ' + $azureResourceGroup)

#Verify psbilbAzureMachineName is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['psbilbAzureMachineName']))
{
  Throw 'Azure Machine Name cannot be null.'
}
$azureMachineName = $OctopusParameters['psbilbAzureMachineName']
Write-Host ('Azure Machine Name: ' + $azureMachineName)

#Verify psbilbAzureLoadBalancer is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['psbilbAzureLoadBalancer']))
{
  Throw 'Azure Load Balancer cannot be null.'
}
$azureLoadBalancer = $OctopusParameters['psbilbAzureLoadBalancer']
Write-Host ('Azure Load Balancer: ' + $azureLoadBalancer)

#Verify psbilbAzureLoadBalancerBackEndPoolName is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['psbilbAzureLoadBalancerBackEndPoolName']))
{
  Throw 'Azure Load Balancer Backend Pool Name cannot be null.'
}
$azureLoadBalancerBackendPoolName = $OctopusParameters['psbilbAzureLoadBalancerBackEndPoolName']
Write-Host ('Azure Load Balancer Backend Pool Name: ' + $azureLoadBalancerBackendPoolName)

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

$loadBalancer = Get-AzureRmLoadBalancer -Name $azureLoadBalancer -ResourceGroupName $azureResourceGroup
If (!$loadBalancer)
{
  Throw 'Could not retrieve Load Balancer info from Azure.'
}

$ap = Get-AzureRmLoadBalancerBackendAddressPoolConfig -Name #{psbilbAzureLoadBalancerBackEndPoolName} -LoadBalancer $loadBalancer

$nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $ap
$nic | Set-AzureRmNetworkInterface

#endregion
