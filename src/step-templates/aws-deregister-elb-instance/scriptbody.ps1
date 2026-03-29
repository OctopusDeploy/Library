# Part 1 of 2
# Part 1 Deregisters an EC2 instance from an ELB
# Part 2 Registers an EC2 instance with an ELB and waits for it to be InService

$ec2Region = $OctopusParameters['ec2Region']
$ec2User = $OctopusParameters['ec2ClientId']
$ec2Credentials = $OctopusParameters['ec2Credentials']
$elbName = $OctopusParameters['elbName']
$instanceId = ""

# Load EC2 credentials (not sure if this is needed when executed from an EC2 box)
try
{
	Write-Host "Loading AWS Credentials..."
	Import-Module AWSPowerShell
	Set-AWSCredentials -AccessKey $ec2User -SecretKey $ec2Credentials
	Set-DefaultAWSRegion $ec2Region
	Write-Host "AWS Credentials Loaded."
}
catch
{
	Write-Error -Message "Failed to load AWS Credentials." -Exception $_.Exception
	Exit 1
}

# Get EC2 Instance
try
{
	$response = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Method Get
	if ($response)
	{
		$instanceId = $response
	}
	else
	{
		Write-Error -Message "Returned Instance ID does not appear to be valid"
		Exit 1
	}
}
catch
{
	Write-Error -Message "Failed to load instance ID from AWS." -Exception $_.Exception
	Exit 1
}

# Deregister the current EC2 instance
Write-Host "Deregistering instance $instanceId from $elbName"
try
{
	Remove-ELBInstanceFromLoadBalancer -LoadBalancerName $elbName -Instance $instanceId -Force
	Write-Host "Instance deregistered"
}
catch
{
	Write-Error -Message "Failed to deregister instance." -Exception $_.Exception
	Exit 1
}