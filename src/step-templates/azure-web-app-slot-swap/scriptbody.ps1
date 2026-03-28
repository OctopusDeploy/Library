$rg = $OctopusParameters["Octopus.Action.Azure.ResourceGroupName"]
$webAppName = $OctopusParameters["Octopus.Action.Azure.WebAppName"]
$destinationSlot = $OctopusParameters["azWebAppSwap.targetSlot"]
$sourceSlot = $OctopusParameters["azWebAppSwap.sourceSlot"]

if([string]::IsNullOrEmpty($sourceSlot))
{
	throw "value for source slot must be provided"
}

$cmdArgs = "-g $rg -n $webAppName -s $sourceSlot"

if(![string]::IsNullOrEmpty($destinationSlot)) {$cmdArgs += " --target-slot $destinationSlot"}

$cmd = "az webapp deployment slot swap $cmdArgs"

write-verbose "command being invoked: $cmd"

Invoke-Expression $cmd