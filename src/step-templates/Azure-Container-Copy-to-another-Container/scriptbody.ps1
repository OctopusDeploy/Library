# Define the source storage account and context
$SourceStorageAccountName = $OctopusParameters['SourceStorageAccountName'];
$SourceStorageAccountKey = $OctopusParameters['SourceStorageAccountKey'];
$SourceContainerName = $OctopusParameters['SourceContainerName'];
$SourceContext = New-AzureStorageContext -StorageAccountName $SourceStorageAccountName -StorageAccountKey $SourceStorageAccountKey
$SourceBlobPrefix = $OctopusParameters['SourceBlobPrefix'];

# Define the destination storage account and context
$DestinationStorageAccountName = $OctopusParameters['DestinationStorageAccountName'];
$DestinationStorageAccountKey = $OctopusParameters['DestinationStorageAccountKey'];
$DestinationContainerName = $OctopusParameters['DestinationContainerName'];
$DestinationContext = New-AzureStorageContext -StorageAccountName $DestinationStorageAccountName -StorageAccountKey $DestinationStorageAccountKey
$DestinationBlobPrefix = $OctopusParameters['DestinationBlobPrefix'];

# Check if container exists, otherwise create it
$isContainerExist = Get-AzureStorageContainer -Context $DestinationContext | Where-Object { $_.Name -eq $DestinationContainerName }
if($isContainerExist -eq $null)
{
    New-AzureStorageContainer -Name $DestinationContainerName -Context $DestinationContext
}

# Get a reference to blobs in the source container
$blobs = $null
if ($SourceBlobPrefix -eq $null) {
    $blobs = Get-AzureStorageBlob -Container $SourceContainerName -Context $SourceContext
}
else {
    $blobs = Get-AzureStorageBlob -Container $SourceContainerName -Context $SourceContext -Prefix $SourceBlobPrefix
}

# Copy blobs from one container to another
if ($DestinationBlobPrefix -eq $null) {
	$blobs | Start-AzureStorageBlobCopy -DestContainer $DestinationContainerName -DestContext $DestinationContext
}
else {
	$uri = $SourceContext.BlobEndPoint + $SourceContainerName +"/" 
	$blobs | ForEach-Object `
    	{ Start-AzureStorageBlobCopy `
	        -SrcUri "$uri$($_.Name)" `
            -Context $SourceContext `
	        -DestContext $DestinationContext `
	        -DestContainer $DestinationContainerName `
	        -DestBlob "$DestinationBlobPrefix/$($_.Name)" `
	    } 
}
    