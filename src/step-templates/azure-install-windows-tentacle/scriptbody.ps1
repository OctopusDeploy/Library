$nsgName = $OctopusParameters["installWinTentacle.azNsgName"]
$resourceGroup = $OctopusParameters["installWinTentacle.azRgName"]
$nsgRulePriority = $OctopusParameters["installWinTentacle.azNsgRulePriority"]
$vmName = $OctopusParameters["installWinTentacle.azVmName"]
$serverUri = $OctopusParameters["instrallTentacle.octoServerUrl"]
$apiKey = $OctopusParameters["installWinTentacle.octoApiKey"]
$rolesRaw = $OctopusParameters["installWinTentacle.octopusRoles"]
$enviroRaw = $OctopusParameters["installWinTentacle.octopusEnvironments"]
$octoThumb = $OctopusParameters["installWinTentacle.octoServerThumb"]
$comStyle = $OctopusParameters["installWinTentacle.tentacleType"]
$hostname = $OctopusParameters["installWinTentacle.tentacleHostName"]
$portNumber = $OctopusParameters["installWinTentacle.portNumber"]

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
$enviroRaw -split "`n" | ForEach-Object { $environments += "--environment $_ "}
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

$remoteScript = @"
`$msiLocation = "`$env:TEMP\`$(new-guid).msi"

if(`$env:PROCESSOR_ARCHITECTURE -eq "x86") 
{
    `$downloadPath = "http://octopus.com/downloads/latest/OctopusTentacle"
}
else
{
    `$downloadPath = "http://octopus.com/downloads/latest/OctopusTentacle64"
}

Invoke-WebRequest -Uri `$downloadPath -OutFile `$msiLocation -UseBasicParsing

Start-Process `$msiLocation /quiet -Wait

Remove-Item `$msiLocation

"@

Write-Host "Installing tentacle on remote machine"

Set-Content -Value $remoteScript -Path ".\script.ps1"

$result = az vm run-command invoke --command-id RunPowerShellScript --name $vmName -g $resourceGroup --scripts "@script.ps1"

$result

$msg = (($result | convertfrom-json).value | where {$_.code -eq "componentstatus/stderr/succeeded"}).message

if(![string]::IsNullOrEmpty($msg))
{
	throw $msg
}

Write-Verbose "hostname: $hostname`noListen: $noListen"

$remoteScript = @"

cd "C:\Program Files\Octopus Deploy\Tentacle"

.\Tentacle.exe create-instance --instance "Tentacle" --config "C:\Octopus\Tentacle.config" --console
.\Tentacle.exe new-certificate --instance "Tentacle" --if-blank --console
.\Tentacle.exe configure --instance "Tentacle" --reset-trust --console
.\Tentacle.exe configure --instance "Tentacle" --home "C:\Octopus" --app "C:\Octopus\Applications" $noListen --console
.\Tentacle.exe configure --instance "Tentacle" --trust "$octoThumb" --console
if('$openFirewall' -eq 'true'){
	New-NetFirewallRule -DisplayName "Octopus Tentacle" -Direction Inbound -LocalPort $portNumber -Protocol TCP -Action Allow
}
.\Tentacle.exe register-with --instance "Tentacle" --server "$serverUri" --apiKey=$apiKey $roles $environments --comms-style $comStyle --force --console
.\Tentacle.exe service --instance "Tentacle" --install --start --console

"@

Write-Host "Configuring tentacle on remote machine"

Set-Content -Value $remoteScript -Path ".\script.ps1"

$result = az vm run-command invoke --command-id RunPowerShellScript --name $vmName -g $resourceGroup --scripts "@script.ps1"

$result

$msg = (($result | convertfrom-json).value | where {$_.code -eq "componentstatus/stderr/succeeded"}).message

if(![string]::IsNullOrEmpty($msg))
{
	throw $msg
}
