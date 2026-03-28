$accessKey = $OctopusParameters['accessKey']
$secretKey = $OctopusParameters['secretKey']
$region = $OctopusParameters['region']

$targetGroupArn = $OctopusParameters['targetGroupArn']

$action = $OctopusParameters['action']

$checkInterval = $OctopusParameters['checkInterval']
$maxChecks = $OctopusParameters['maxChecks']

$awsProfile = (get-date -Format '%y%d%M-%H%m').ToString() # random

if (Get-Module | Where-Object { $_.Name -like "AWSPowerShell*" }) {
	Write-Host "AWS PowerShell module is already loaded."
} else {
	$awsModule = Get-Module -ListAvailable | Where-Object {  $_.Name -like "AWSPowerShell*" }
	if (!($awsModule)) {
    	Write-Error "AWSPowerShell / AWSPowerShell.NetCore not found"
        return
    } else {
    	Import-Module $awsModule.Name
        Write-Host "Imported Module: $($awsModule.Name)"
    }
}

function GetCurrentInstanceId
{
    Write-Host "Getting instance id"

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

	$response
}

function GetTarget
{
    $instanceId = GetCurrentInstanceId

    $target = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.TargetDescription
    $target.Id = $instanceId
    
    Write-Host "Current instance id: $instanceId"

    return $target
}

function GetInstanceState
{
	$state = (Get-ELB2TargetHealth -TargetGroupArn $targetGroupArn -Target $target -AccessKey $accessKey -SecretKey $secretKey -Region $region).TargetHealth.State

	Write-Host "Current instance state: $state"

	return $state
}

function WaitForState
{
    param([string]$expectedState)

    $instanceState = GetInstanceState -arn $targetGroupArn -target $target

    if ($instanceState -eq $expectedState)
    {
        return
    }

    $checkCount = 0

    Write-Host "Waiting for instance state to be $expectedState"
    Write-Host "Maximum Checks: $maxChecks"
    Write-Host "Check Interval: $checkInterval"

    while ($instanceState -ne $expectedState -and $checkCount -le $maxChecks)
    {	
	    $checkCount += 1
	
	    Write-Host "Waiting for $checkInterval seconds for instance state to be $expectedState"
	    Start-Sleep -Seconds $checkInterval
	
	    if ($checkCount -le $maxChecks)
	    {
		    Write-Host "$checkCount/$maxChecks Attempts"
	    }
	
	    $instanceState = GetInstanceState
    }

    if ($instanceState -ne $expectedState)
    {
	    Write-Error -Message "Instance state is not $expectedState, giving up."
	    Exit 1
    }
}

function DeregisterInstance
{
    Write-Host "Deregistering instance from $targetGroupArn"
    Unregister-ELB2Target -TargetGroupArn $targetGroupArn -Target $target -AccessKey $accessKey -SecretKey $secretKey -Region $region
    WaitForState -expectedState "unused"
    Write-Host "Instance deregistered"
}

function RegisterInstance
{
    Write-Host "Registering instance with $targetGroupArn"
    Try {
    	Register-ELB2Target -TargetGroupArn $targetGroupArn -Target $target -AccessKey $accessKey -SecretKey $secretKey -Region $region
    } Catch {
    	Write-Host $Error[0]
    }
    WaitForState -expectedState "healthy"
    Write-Host "Instance registered"
}

$target = GetTarget

switch ($action)
{
    "deregister" { DeregisterInstance }
    "register" { RegisterInstance }
}