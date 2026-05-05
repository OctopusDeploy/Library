Write-Output "Resource group name: $($OctopusParameters['Azure.LoadBalancerCreateRule.ResourceGroupName'])"
Write-Output "Load balancer name : $($OctopusParameters['Azure.LoadBalancerCreateRule.LoadBalancerName'])"
Write-Output "Rule name: $($OctopusParameters['Azure.LoadBalancerCreateRule.RuleName'])"

Write-Output "Protocol: $($OctopusParameters['Azure.LoadBalancerCreateRule.Protocol'])"
Write-Output "Frontend port: $($OctopusParameters['Azure.LoadBalancerCreateRule.FrontendPort'])"
Write-Output "Backend port: $($OctopusParameters['Azure.LoadBalancerCreateRule.BackendPort'])"
Write-Output "Healt probe name: $($OctopusParameters['Azure.LoadBalancerCreateRule.HealthProbeName'])"
Write-Output "Idle timeout: $($OctopusParameters['Azure.LoadBalancerCreateRule.IdleTimeout'])"
Write-Output "Load distribution: $($OctopusParameters['Azure.LoadBalancerCreateRule.LoadDistribution'])"

$loadBalancer = Get-AzureRmLoadBalancer -ResourceGroupName $OctopusParameters['Azure.LoadBalancerCreateRule.ResourceGroupName'] -name $OctopusParameters['Azure.LoadBalancerCreateRule.LoadBalancerName']
$rule = Get-AzureRmLoadBalancerRuleConfig -Name $OctopusParameters['Azure.LoadBalancerCreateRule.RuleName'] -LoadBalancer $loadBalancer -ErrorAction:SilentlyContinue
$healthProbe = Get-AzureRmLoadBalancerProbeConfig -name $OctopusParameters['Azure.LoadBalancerCreateRule.HealthProbeName'] -LoadBalancer $loadBalancer -ErrorAction:SilentlyContinue

if($rule -eq $null)
{
	#Create rule
    Write-output "Creating load balancer rule with name: $($OctopusParameters['Azure.LoadBalancerCreateRule.RuleName']) in load balancer: $($OctopusParameters['Azure.LoadBalancerCreateRule.LoadBalancerName']) in resource group: $($OctopusParameters['Azure.LoadBalancerCreateRule.ResourceGroupName'])"
	
    $loadBalancer | Add-AzureRmLoadBalancerRuleConfig -Name $OctopusParameters['Azure.LoadBalancerCreateRule.RuleName'] `
		-FrontendIpConfigurationId ($loadBalancer.FrontendIpConfigurations[0].Id) `
		-Protocol $OctopusParameters['Azure.LoadBalancerCreateRule.Protocol'] `
		-FrontendPort $OctopusParameters['Azure.LoadBalancerCreateRule.FrontendPort'] `
		-BackendPort $OctopusParameters['Azure.LoadBalancerCreateRule.BackendPort'] `
		-BackendAddressPoolId ($loadBalancer.BackendAddressPools[0].Id) `
		-ProbeId ($healthProbe.Id) `
		-IdleTimeoutInMinutes $OctopusParameters['Azure.LoadBalancerCreateRule.IdleTimeout'] `
		-LoadDistribution $OctopusParameters['Azure.LoadBalancerCreateRule.LoadDistribution']
}
else
{
	#Update rule
    Write-output "Updating load balancer rule with name: $($OctopusParameters['Azure.LoadBalancerCreateRule.RuleName']) in load balancer: $($OctopusParameters['Azure.LoadBalancerCreateRule.LoadBalancerName']) in resource group: $($OctopusParameters['Azure.LoadBalancerCreateRule.ResourceGroupName'])"
	
	$loadBalancer | Set-AzureRmLoadBalancerRuleConfig -Name $OctopusParameters['Azure.LoadBalancerCreateRule.RuleName'] `
		-FrontendIpConfigurationId ($loadBalancer.FrontendIpConfigurations[0].Id) `
		-Protocol $OctopusParameters['Azure.LoadBalancerCreateRule.Protocol'] `
		-FrontendPort $OctopusParameters['Azure.LoadBalancerCreateRule.FrontendPort'] `
		-BackendPort $OctopusParameters['Azure.LoadBalancerCreateRule.BackendPort'] `
		-BackendAddressPoolId ($loadBalancer.BackendAddressPools[0].Id) `
		-ProbeId ($healthProbe.Id) `
		-IdleTimeoutInMinutes $OctopusParameters['Azure.LoadBalancerCreateRule.IdleTimeout'] `
		-LoadDistribution $OctopusParameters['Azure.LoadBalancerCreateRule.LoadDistribution']
}

Write-host "Saving loadbalancer"
Set-AzureRmLoadBalancer -LoadBalancer $loadBalancer