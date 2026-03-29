# Part 2 of 2
# Part 1 Deregisters an EC2 instance from an ELB
# Part 2 Registers an EC2 instance with an ELB and waits for it to be InService

$ec2Region = $OctopusParameters['ec2Region']
$ec2User = $OctopusParameters['ec2ClientId']
$ec2Credentials = $OctopusParameters['ec2Credentials']
$elbName = $OctopusParameters['elbName']
$instanceId = ""
$registrationCheckInterval = $OctopusParameters['registrationCheckInterval']
$maxRegistrationCheckCount = $OctopusParameters['maxRegistrationCheckCount']

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

# Register the current EC2 instance
Write-Host "Registering instance $instanceId with $elbName."
try
{
	Register-ELBInstanceWithLoadBalancer -LoadBalancerName $elbName -Instance $instanceId
	Write-Host "Instance Registered, waiting for registration to complete."
	
	$instanceState = (Get-ELBInstanceHealth -LoadBalancerName $elbName -Instance $instanceId).State
	Write-Host "Current State: $instanceState"
	
	$checkCount = 0
	
	Write-Host "Retry Parameters:"
	Write-Host "Maximum Checks: $maxRegistrationCheckCount"
	Write-Host "Check Interval: $registrationCheckInterval"
	
	While ($instanceState -ne "InService" -and $checkCount -le $maxRegistrationCheckCount)
	{	
		$checkCount += 1
		
		# Wait a bit until we check the status
		Write-Host "Waiting for $registrationCheckInterval seconds for instance to register"
		Start-Sleep -Seconds $registrationCheckInterval
		
		if ($checkCount -le $maxRegistrationCheckCount)
		{
			Write-Host "$checkCount/$maxRegistrationCheckCount Attempts"
		}
		
		$instanceState = (Get-ELBInstanceHealth -LoadBalancerName $elbName -Instance $instanceId).State
		
		Write-Host "Current instance state: $instanceState"
	}
	
	if ($instanceState -eq "InService")
	{
		Write-Host "Registration complete."
	}
	else
	{
		Write-Error -Message "Failed to register instance: $instanceState"
		Exit 1
	}
}
catch
{
	Write-Error -Message "Failed to Register instance." -Exception $_.Exception
	Exit 1
}