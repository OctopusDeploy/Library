$SourceStorageAccountName = $OctopusParameters['SourceStorageAccountName'];
$SourceStorageAccountKey = $OctopusParameters['SourceStorageAccountKey'];
$DestinationStorageAccountName = $OctopusParameters['DestinationStorageAccountName'];
$DestinationStorageAccountKey = $OctopusParameters['DestinationStorageAccountKey'];
$ContainersIncluded = $OctopusParameters['ContainersIncluded'];
$ContainersExcluded = $OctopusParameters['ContainersExcluded'];

$AzCopy = Join-Path ${env:ProgramFiles(x86)} "Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

function AzCopyContainer($containerName)
{
    &$AzCopy /Source:http://$($SourceStorageAccountName).blob.core.windows.net/$containerName `
	/Dest:http://$($DestinationStorageAccountName).blob.core.windows.net/$containerName `
	/SourceKey:$SourceStorageAccountKey `
	/DestKey:$DestinationStorageAccountKey `
	/S /XO /XN /V | Out-Host
}

# List all Containers
$ctx = New-AzureStorageContext -StorageAccountName $SourceStorageAccountName -StorageAccountKey $SourceStorageAccountKey
$containers = Get-AzureStorageContainer -Context $ctx

	
# If Containers Included is there  => Copy Included Only 
if($ContainersIncluded)
{
	# Parse the Included list
	$ContainersIncluded.Split(",") | foreach {
		AzCopyContainer $_
	}
}

# If Containers Excluded is there, and no Included => Copy all except excluded
elseif(!$ContainersIncluded -and $ContainersExcluded)
{
	#Parse the exclusion list
	[Collections.Generic.List[String]]$lst = $ContainersExcluded.Split(",")

	# Loop through all the containers, and
	foreach ($container in $containers) 
	{
		if($lst.Contains($container.Name)) {
			continue
		}
		else 
		{
			$containerName = $container.Name
            AzCopyContainer $containerName
		}
	} 
}

# Copy all containers
else
{
	# Loop through all the containers, and
	foreach ($container in $containers) 
	{
		$containerName = $container.Name
        AzCopyContainer $containerName
	} 
}