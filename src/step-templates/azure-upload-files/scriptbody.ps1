#Sets the Permissions to public if the selection is true
if ([boolean]::Parse($doRecurse)) 
{
    
	$recurse = "-Recurse"

}

if ([boolean]::Parse($doForce)) 
{
    
	$force = "-Force"

}

#--------------------------------------------------------------------
#Checking to see if Azure is installed on the computer
$name = 'Azure'

Write-Output "Checking if Azure Powershell is installed"

if(Get-Module -ListAvailable | Where-Object {$_.name -eq $name})
{
	(Get-Module -ListAvailable | Where-Object{ $_.Name -eq $name}) |
	Select Version, Name, Author, PowerShellVersion | Format-List;
	Write-Output "Azure Powershell is installed"
}
else
{
	#Provides the link to install Azure Powershell, if it is not installed
	Write-Warning "Please install Azure Powershell. To install Azure Powershell go to http://bit.ly/AzurePowershellDownload"
	Exit 1
}



#--------------------------------------------------------------------

#Initialises the Azure Credentials based on the Storage Account Name and the Storage Account Key, 
#so that we can invoke the APIs further down. 
$storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

#--------------------------------------------------------------------

Get-ChildItem -Path $localFolder -File $recurse | Set-AzureStorageBlobContent -Container $containerName -Blob $blobName -Context $storageContext $force

Write-Output "All files in $localFolder uploaded to $containerName!"
