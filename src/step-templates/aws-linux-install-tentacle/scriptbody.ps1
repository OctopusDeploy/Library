$sgName = $OctopusParameters["awsInstallLinuxTentacle.awsSGName"]
$instanceId = $OctopusParameters["awsInstallLinuxTentacle.awsVmInstanceId"]
$serverUri = $OctopusParameters["instrallTentacle.octoServerUrl"]
$apiKey = $OctopusParameters["awsInstallLinuxTentacle.octoApiKey"]
$rolesRaw = $OctopusParameters["awsInstallLinuxTentacle.octopusRoles"]
$enviroRaw = $OctopusParameters["awsInstallLinuxTentacle.octopusEnvironments"]
$octoThumb = $OctopusParameters["awsInstallLinuxTentacle.octoServerThumb"]
$comStyle = $OctopusParameters["awsInstallLinuxTentacle.tentacleType"]
$hostname = $OctopusParameters["awsInstallLinuxTentacle.tentacleHostName"]
$tentacleName = $OctopusParameters["awsInstallLinuxTentacle.tentacleName"]
$portNumber = $OctopusParameters["awsInstallLinuxTentacle.portNumber"]

Write-Host "Parsing Parameters"

if([string]::IsNullOrEmpty($sgName))
{
	throw "Security Group name must be provided"
}

if([string]::IsNullOrEmpty($instanceId))
{
	throw "Instance Id must be provided"
}

if([string]::IsNullOrEmpty($apiKey))
{
	throw "apiKey must be provided"
}

if([string]::IsNullOrEmpty($rolesRaw))
{
	throw "At least one role must be defined"
}

if([string]::IsNullOrEmpty($enviroRaw))
{
	throw "At least one environment must be defined"
}

if([string]::IsNullOrEmpty($octoThumb))
{
	throw "octo thumbprint must be provided"
}

$roles = ""
$rolesRaw -split "`n" | ForEach-Object { $roles += "--role $_ "}
$roles = $roles.TrimEnd(' ')

$environments = ""
$enviroRaw -split "`n" | ForEach-Object { $environments += "--env $_ "}
$environments = $environments.TrimEnd(' ')

if($comStyle -eq "TentaclePassive")
{
	if([string]::IsNullOrEmpty($hostname))
    {
    	$hostname = aws ec2 describe-instances --filters "Name=instance-id,Values=$instanceId" --query "Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp" --output=text
        $hostname = $hostname.Trim("`n")
    }
    
    $noListen = "--port $portNumber --noListen `"false`""
    $comStyle += " --publicHostName='$hostname'"
    $openFirewall = 'true'
}
else
{
	$noListen = "--noListen `"true`""
    $openFirewall = 'false'
}

if([string]::IsNullOrEmpty($tentacleName))
{
	$tentacleName = $hostname
}

if($openFirewall -eq 'true')
{
	Write-Host "Checking SG..." -NoNewline
    $sgCheck = aws ec2 describe-security-groups --group-names $sgName --output json --filters Name=ip-permission.from-port,Values=$portNumber Name=ip-permission.cidr,Values='0.0.0.0/0' | convertfrom-json
    
    if($sgCheck.SecurityGroups.count -eq 0)
    {
		Write-Host "Creating SG Rule"
    	aws ec2 authorize-security-group-ingress --group-name $sgName --ip-permissions IpProtocol=tcp,ToPort=$portNumber,FromPort=$portNumber,IpRanges='[{CidrIp=0.0.0.0/0,Description="OctopusListeningTentacle"}]'
	}
    else
    {
    	Write-Host "Found Existing SG Rule"
    }
}

Write-Verbose "hostname: $hostname`nnoListen: $noListen"

$remoteScript = @"
{
	"commands": [
    	"#!/bin/bash",
		"curl -L https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle -o /tmp/tentacle-linux_x64.tar.gz -fsS",
		"if [ ! -d \"/opt/octopus\" ]; then sudo mkdir /opt/octopus; fi",
		"tar xvzf /tmp/tentacle-linux_x64.tar.gz -C /opt/octopus",
		"rm /tmp/tentacle-linux_x64.tar.gz",
		"cd /opt/octopus/tentacle",
		"sudo /opt/octopus/tentacle/Tentacle create-instance --config '/etc/octopus/default/tentacle-default.config'",
		"sudo chmod a+rwx /etc/octopus/default/tentacle-default.config",
		"/opt/octopus/tentacle/Tentacle new-certificate --if-blank",
		"/opt/octopus/tentacle/Tentacle configure --port $portNumber --noListen False --reset-trust --app '/home/Octopus/Applications'",
		"/opt/octopus/tentacle/Tentacle configure --trust $octoThumb",
		"echo 'Registering the Tentacle $name with server $serverUri in environment $environments with role $roles'",
		"/opt/octopus/tentacle/Tentacle register-with --server '$serverUri' --apiKey '$apikey' $environments $roles --comms-style $comStyle --name '$tentacleName' --force",
		"sudo /opt/octopus/tentacle/Tentacle service --install --start"
	]
}
"@

Write-Host "Installing tentacle on remote machine"
$guid = (new-guid).guid
Set-Content -Value $remoteScript -Path "$env:Temp/$guid.json"

write-verbose $remoteScript

write-verbose "aws ssm send-command --document-name `"AWS-RunShellScript`" --instance-ids `"$instanceId`" --parameters `"file://$env:Temp/$guid.json`""
try {
	$cmdResponse = aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids "$instanceId" --parameters "file://$env:Temp/$guid.json" --query "Command" --output json | convertfrom-json
    $cmdId = $cmdResponse.CommandId
    $errorResponse = aws ssm get-command-invocation --command-id "$cmdId" --instance-id "$instanceId" --output json | convertfrom-json
    
    while($errorResponse.Status -eq 'InProgress')
    {
    	write-verbose "`nStatus: $($errorResponse.Status)"
    	$errorResponse = aws ssm get-command-invocation --command-id "$cmdId" --instance-id "$instanceId" --output json | convertfrom-json
    }
    
    write-verbose "`nErrorResponse: $errorResponse`n"
    
    if(![string]::IsNullOrEmpty($errorResponse.StandardErrorContent))
    {
    	throw $errorResponse.StandardErrorContent
    }
}
finally {
	remove-item "$env:Temp\$guid.json"
}
