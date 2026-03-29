$nsgName = $OctopusParameters["installLinuxTentacle.azNsgName"]
$resourceGroup = $OctopusParameters["installLinuxTentacle.azRgName"]
$nsgRulePriority = $OctopusParameters["installLinuxTentacle.azNsgRulePriority"]
$vmName = $OctopusParameters["installLinuxTentacle.azVmName"]
$serverUri = $OctopusParameters["instrallTentacle.octoServerUrl"]
$apiKey = $OctopusParameters["installLinuxTentacle.octoApiKey"]
$rolesRaw = $OctopusParameters["installLinuxTentacle.octopusRoles"]
$enviroRaw = $OctopusParameters["installLinuxTentacle.octopusEnvironments"]
$octoThumb = $OctopusParameters["installLinuxTentacle.octoServerThumb"]
$comStyle = $OctopusParameters["installLinuxTentacle.tentacleType"]
$hostname = $OctopusParameters["installLinuxTentacle.tentacleHostName"]
$portNumber = $OctopusParameters["installLinuxTentacle.portNumber"]

Write-Host "Parsing Parameters"

if([string]::IsNullOrEmpty($rolesRaw))
{
	throw "At least one role must be defined"
}

if([string]::IsNullOrEmpty($enviroRaw))
{
	throw "At least one environment must be defined"
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
    	$hostname = az vm show -d -g $resourceGroup -n $vmName --query publicIps -o tsv
        $hostname = $hostname.Trim("`n")
    }

    $noListen = "--port $portNumber --noListen `"false`""
    $comStyle += " --publicHostName=`"$hostname`""
    $openFirewall = 'true'
}
else
{
	$noListen = "--noListen `"true`""
    $openFirewall = 'false'
}

if($openFirewall -eq 'true')
{
	Write-Host "Creating NSG Rule"
	az network nsg rule create --name "OctopusTentacle" --nsg-name $nsgName --priority $nsgRulePriority --resource-group $resourceGroup --direction Inbound --destination-port-ranges $portNumber
}

Write-Verbose "hostname: $hostname`noListen: $noListen"

$remoteScript = @"

printf '%s\n' "Test case x failed" >&2
exit 1

configFilePath="/etc/octopus/default/tentacle-default.config"
appPath="/home/Octopus/Applications"

# try curl
{
    curl -L https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle --output /tmp/tentacle-linux_x64.tar.gz -fsS
} || {
    wget https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle -O /tmp/tentacle-linux_x64.tar.gz -fsS
}

if [ ! -d "/opt/octopus" ]; then
  mkdir /opt/octopus
fi

tar xvzf /tmp/tentacle-linux_x64.tar.gz -C /opt/octopus
rm /tmp/tentacle-linux_x64.tar.gz

cd /opt/octopus/tentacle

sudo /opt/octopus/tentacle/Tentacle create-instance --config "`$configFilePath"
sudo chmod a+rwx `$configFilePath
/opt/octopus/tentacle/Tentacle new-certificate --if-blank
/opt/octopus/tentacle/Tentacle configure --port $portNumber --noListen False --reset-trust --app "`$appPath"
/opt/octopus/tentacle/Tentacle configure --trust $octoThumb
echo "Registering the Tentacle $name with server $serverUri in environment $environments with role $roles"
/opt/octopus/tentacle/Tentacle register-with --server "$serverUri" --apiKey "$apikey" --name "$name" $environments $roles --comms-style $comStyle --force
sudo /opt/octopus/tentacle/Tentacle service --install --start

"@

Write-Host "Installing tentacle on remote machine"
$scriptGuid = (new-guid).guid
Set-Content -Value $remoteScript -Path ".\$scriptGuid.ps1"

$result = az vm run-command invoke --command-id RunShellScript --name $vmName -g $resourceGroup --scripts "@script.ps1"

$result

$msg = ($result | convertfrom-json).value[0].message

if($msg -match "(?<=\[stderr\]).+")
{
	throw $msg
}

remove-item ".\$scriptGuid.ps1"
