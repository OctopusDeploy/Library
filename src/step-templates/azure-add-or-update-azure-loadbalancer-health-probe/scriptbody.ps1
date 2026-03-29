

Write-Output "Resource group name: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ResourceGroupName'])"
Write-Output "Load balancer name : $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.LoadBalancerName'])"
Write-Output "Health probe name: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName'])"

Write-Output "Protocol: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'])"
Write-Output "Path: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Path'])"
Write-Output "Port: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Port'])"
Write-Output "Interval: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Interval'])"
Write-Output "Probe count: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ProbeCount'])"


$loadBalancer = Get-AzureRmLoadBalancer -ResourceGroupName $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ResourceGroupName'] -name $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.LoadBalancerName']
$healthProbe = Get-AzureRmLoadBalancerProbeConfig -name $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName'] -LoadBalancer $loadBalancer  -ErrorAction:SilentlyContinue

if($healthProbe -eq $null)
{
	#Create healthProbe
	Write-Output "Creating healt probe: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName']) on load balancer: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.LoadBalancerName']) in resource group: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ResourceGroupName'])"
	
	if($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'] -eq "http")
	{
		#path only used in http
		$loadBalancer  | Add-AzureRmLoadBalancerProbeConfig -Name $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName'] `
			-RequestPath  $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Path'] `
			-Protocol $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'] `
			-Port $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Port']  `
			-IntervalInSeconds $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Interval'] `
			-ProbeCount $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ProbeCount'] 
	}
	else
	{
		# Path is not part of tcp config
		$loadBalancer  | Add-AzureRmLoadBalancerProbeConfig -Name $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName'] `
			-Protocol $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'] `
			-Port $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Port']  `
			-IntervalInSeconds $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Interval'] `
			-ProbeCount $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ProbeCount']
	}
}
else
{
	#Update healthProbe
	Write-Output "Updating healt probe: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName']) on load balancer: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.LoadBalancerName']) in resource group: $($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ResourceGroupName'])"
	
	if($OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'] -eq "http")
	{
		#path only used in http
		$loadBalancer  | Set-AzureRmLoadBalancerProbeConfig -Name $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName'] `
			-RequestPath  $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Path'] `
			-Protocol $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'] `
			-Port $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Port']  `
			-IntervalInSeconds $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Interval'] `
			-ProbeCount $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ProbeCount'] 
	}
	else
	{
		# Path is not part of tcp config
		$loadBalancer  | Set-AzureRmLoadBalancerProbeConfig -Name $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.HealthProbeName'] `
			-Protocol $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Protocol'] `
			-Port $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Port']  `
			-IntervalInSeconds $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.Interval'] `
			-ProbeCount $OctopusParameters['Azure.LoadBalancerCreateHealthProbe.ProbeCount']
	}
}

Write-Host "Save changes to loadbalancer"
Set-AzureRmLoadBalancer -LoadBalancer $loadBalancer