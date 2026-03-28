$sgName = $OctopusParameters["awsInstallWinTentacle.awsSGName"]
$instanceId = $OctopusParameters["awsInstallWinTentacle.awsVmInstanceId"]
$serverUri = $OctopusParameters["awsInstallWinTentacle.octoServerUrl"]
$apiKey = $OctopusParameters["awsInstallWinTentacle.octoApiKey"]
$rolesRaw = $OctopusParameters["awsInstallWinTentacle.octopusRoles"]
$enviroRaw = $OctopusParameters["awsInstallWinTentacle.octopusEnvironments"]
$octoThumb = $OctopusParameters["awsInstallWinTentacle.octoServerThumb"]
$comStyle = $OctopusParameters["awsInstallWinTentacle.tentacleType"]
$hostname = $OctopusParameters["awsInstallWinTentacle.tentacleHostName"]
$tentacleName = $OctopusParameters["awsInstallWinTentacle.tentacleName"]
$portNumber = $OctopusParameters["awsInstallWinTentacle.portNumber"]

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

    $noListen = "--port $portNumber --noListen 'false'"
    $comStyle += " --publicHostName='$hostname'"
    $openFirewall = 'true'
}
else
{
	$noListen = "--noListen 'true'"
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
$remoteGuid = (new-guid).guid
Write-Verbose "hostname: $hostname`nnoListen: $noListen"

$remoteScript = @"
{ "commands": [
"if('$env:PROCESSOR_ARCHITECTURE' -eq \"x86\") {Invoke-WebRequest -Uri 'http://octopus.com/downloads/latest/OctopusTentacle' -OutFile `$env:TEMP/$remoteGuid.msi -UseBasicParsing} else { Invoke-WebRequest -Uri 'http://octopus.com/downloads/latest/OctopusTentacle64' -OutFile `$env:TEMP/$remoteGuid.msi -UseBasicParsing}",
"Start-Process `$env:TEMP/$remoteGuid.msi /quiet -Wait",
"Remove-Item \"`$env:TEMP/$remoteGuid.msi\"",
"cd 'C:/Program Files/Octopus Deploy/Tentacle'",
".\\Tentacle.exe create-instance --instance 'Tentacle' --config 'C:/Octopus/Tentacle.config' --console",
".\\Tentacle.exe new-certificate --instance 'Tentacle' --if-blank --console",
".\\Tentacle.exe configure --instance 'Tentacle' --reset-trust --console",
".\\Tentacle.exe configure --instance 'Tentacle' --home 'C:/Octopus/' --app 'C:/Octopus/Applications' $noListen --console",
".\\Tentacle.exe configure --instance 'Tentacle' --trust '$octoThumb' --console",
"if('$openFirewall' -eq 'true'){New-NetFirewallRule -DisplayName 'Octopus Tentacle' -Direction Inbound -LocalPort $portNumber -Protocol TCP -Action Allow}",
".\\Tentacle.exe register-with --instance 'Tentacle' --server '$serverUri' --apiKey=$apiKey $roles $environments --comms-style $comStyle --force --console",
".\\Tentacle.exe service --instance 'Tentacle' --install --start --console"
]}
"@

Write-Host "Installing tentacle on remote machine"
$guid = (new-guid).guid
Set-Content -Value $remoteScript.Replace('`r','') -Path "$env:Temp/$guid.json"

write-verbose $remoteScript

write-verbose "aws ssm send-command --document-name AWS-RunPowerShellScript --instance-ids $instanceId --parameters file://$env:Temp/$guid.json"
try {
	$cmdResponse = aws ssm send-command --document-name "AWS-RunPowerShellScript" --instance-ids "$instanceId" --parameters "file://$env:Temp/$guid.json" --query "Command" --output json | convertfrom-json
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
