# Check if Windows Azure Powershell is avaiable 
try{ 
    Import-Module Azure -ErrorAction Stop
}catch{
    throw "Windows Azure Powershell not found! Please make sure to install them from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
}


$dateTime = get-date -Format u
$blobName = "Deployment-Backup/$DatabaseName/$dateTime.bacpac"
Write-Host "Using blobName: $blobName"

# Create Database Connection
$securedPassword = ConvertTo-SecureString -String $DatabasePassword -asPlainText -Force
$serverCredential = new-object System.Management.Automation.PSCredential($DatabaseUsername, $securedPassword) 
$databaseContext = New-AzureSqlDatabaseServerContext -ServerName $DatabaseServerName -Credential $serverCredential

# Create Storage Connection
$storageContext = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $StorageKey

# Initiate the Export
$operationStatus = Start-AzureSqlDatabaseExport -StorageContext $storageContext -SqlConnectionContext $databaseContext -BlobName $blobName -DatabaseName $DatabaseName -StorageContainerName $StorageContainerName

# Wait for the operation to finish
do{
    $status = Get-AzureSqlDatabaseImportExportStatus -Request $operationStatus    
    Start-Sleep -s 3
    $progress =$status.Status.ToString()
    Write-Host "Waiting for database export completion. Operation status: $progress" 
}until ($status.Status -eq "Completed")
Write-Host "Database export is complete"