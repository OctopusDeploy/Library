$webAppName = $OctopusParameters["Octopus.Action.Azure.WebAppName"]
$rg = $OctopusParameters["Octopus.Action.Azure.ResourceGroupName"]

$trafficDistro = $OctopusParameters["azWebAppSetTraffic.trafficDistro"]

$cmdArgs = "--name $webAppName --resource-group $rg" 

$cmdAction = "clear"

write-host "Checking distribution"
if(![string]::IsNullOrEmpty($trafficDistro))
{
	$distribution = ""

	$trafficDistro -split "`n" | ForEach-Object { $distribution += "$_ "}

	$distribution = $distribution.TrimEnd(' ')
    
    $cmdArgs += " --distribution $distribution"
    
    $cmdAction = "set"
}


$cmd = "az webapp traffic-routing $cmdAction $cmdArgs"

write-verbose "cmd to invoke: $cmd"

write-host "setting distributions"
invoke-expression $cmd
