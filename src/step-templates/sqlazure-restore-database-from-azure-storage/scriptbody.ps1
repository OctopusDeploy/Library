#Check for the PowerShell cmdlets
try{ 
    Import-Module Azure -ErrorAction Stop
}catch{
    
    $azureServiceModulePath = "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
    Write-Output "Unable to find the module checking $azureServiceModulePath" 
    
    try{
        Import-Module $azureServiceModulePath
        
    }
    catch{
        throw "Windows Azure PowerShell not found! Please make sure to install them from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
    }
}

function Set-TempAzureSubscription{
    param(   
        [Parameter(Mandatory=$true)][string] $subscriptionId,
        [Parameter(Mandatory=$true)][string] $subscriptionName,
        [Parameter(Mandatory=$true)][string] $managementCertificate
    )

    #Ensure no other subscriptions or accounts    
    Get-AzureSubscription | ForEach-Object { 
        $id = $_.SubscriptionId 
        Write-Output "Removing Subscription $id"
        Remove-AzureSubscription -SubscriptionId $id -Force
    }

    #Ensure there are no other 
    Get-AzureAccount | ForEach-Object { Remove-AzureAccount $_.ID -Force }
   
    [byte[]]$certificateData = [System.Convert]::FromBase64String($managementCertificate)
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2] $certificateData

    Set-AzureSubscription -Certificate $certificate -SubscriptionId $subscriptionId -SubscriptionName $subscriptionName
    Select-AzureSubscription $subscriptionName

    Write-Output "Azure Subscription set Id: $subscriptionId Name: $subscriptionName "

    $subscription = Get-AzureSubscription -Current

    return  $subscription
}


function Restore-SqlAzureDatabase{
    Param(    
    [Parameter(Mandatory=$true)][string]$databaseServerName,
    [Parameter(Mandatory=$true)][string]$databaseName,
    [Parameter(Mandatory=$true)][string]$edition,
    [Parameter(Mandatory=$true)][string]$serviceObjectiveName, 
    [Parameter(Mandatory=$true)][string]$storageName,
    [Parameter(Mandatory=$true)][string]$containerName,
    [Parameter(Mandatory=$true)][string]$sqlAdminUser,                       
    [Parameter(Mandatory=$true)][string]$sqlAdminPassword,
    [Parameter(Mandatory=$true)][string]$bacpacFileName,    
    [Parameter(Mandatory=$false)][bool]$errorIfDatabaseExists=$true
    )

    $subscription = Get-AzureSubscription -Current 
         
    $storageKey = (Get-AzureStorageKey -StorageAccountName $storageName).Primary
    $storageCtx = New-AzureStorageContext -storageaccountname $storageName -storageaccountkey $storageKey
    $password = $sqlAdminPassword | ConvertTo-SecureString -asPlainText -Force                                                      
    $sqlCred = New-Object System.Management.Automation.PSCredential($sqlAdminUser,$password)
    $sqlCtx = New-AzureSqlDatabaseServerContext -ServerName $databaseServerName -Credential $sqlCred    
  
    $databases = Get-AzureSqlDatabase -ServerName $databaseServerName

    #Check to see there is a database on the server
    Foreach ($d in $databases){
        if($d.Name -eq $databaseName){
            $database = $d
            break
        }    
    }

    if ($database -eq $null) {
        Write-Output "The SQL Azure Database: $databaseName WAS NOT found on $databaseServerName"  
    }
     
    if($database -ne $null){
        if ($errorIfDatabaseExists -eq $true) {
            Write-Output "A database named $databaseName already exists. If you wish to override this database set the -errorIfDatabaseExists parameter to false." 
            return;
        } else {
            #Delete the existing database.
            Write-Output "The SQL Azure Database: $databaseName WAS found on $databaseServerName"  
            Write-Output "WARNING! Removing SQL Azure database: $databaseName"
            Remove-AzureSqlDatabase -ServerName $databaseServerName -DatabaseName $databaseName -Force
        }
    } 

    Write-Output "Starting database import..."
    $importRequest = Start-AzureSqlDatabaseImport -SqlConnectionContext $sqlCtx -StorageContext $storageCtx -StorageContainerName $containerName -DatabaseName $databaseName -BlobName $bacpacFileName -Edition $edition
    
    Write-Output "Database import request submitted.  Request Id: $($importRequest.RequestGuid)"  

    Write-Output "Checking import status..."
    $status = Get-AzureSqlDatabaseImportExportStatus -Username $sqlAdminUser -Password $sqlAdminPassword -ServerName $databaseServerName -RequestId $importRequest.RequestGuid
    Write-Output "Status: $($status.Status)"
    
    while($status.Status.StartsWith("Running") -Or $status.Status.StartsWith("Pending")){
        Start-Sleep -s 10
        Write-Output "Checking import status..."  
        $status = Get-AzureSqlDatabaseImportExportStatus -Username $sqlAdminUser -Password $sqlAdminPassword -ServerName $databaseServerName -RequestId $importRequest.RequestGuid
        Write-Output "Status: $($status.Status)" 
    }

    Get-AzureSqlDatabaseImportExportStatus -Username $sqlAdminUser -Password $sqlAdminPassword -ServerName $databaseServerName -RequestId $importRequest.RequestGuid   

    if ($status.Status -eq "Completed") {
        Write-Output "Updating database service objective..."

        #Get the service objective.
        $serviceObjective = Get-AzureSqlDatabaseServiceObjective -ServerName $databaseServerName -ServiceObjectiveName $serviceObjectiveName
        Set-AzureSqlDatabase -ConnectionContext $sqlCtx -DatabaseName $databaseName -Force -ServiceObjective $serviceObjective
        
        Write-Output "Updated database service objective." 
    }

    return $importRequest
}


#Set the Azure Subscription
$subscription = Set-TempAzureSubscription -managementCertificate $AzureManagementCertificate -subscriptionId $AzureSubscriptionId -subscriptionName $AzureSubscriptionName 

Write-Output "============================================================="
Write-Output "Using SQL Azure Server $SQLAzureServerName"
Write-Output "Using Azure Storage Account: $AzureStorageAccountName"
Write-Output "Using Azure Storeage Container: $AzureStorageContainerName"
Write-Output "Using bacpac file: $BacPacFileName"
Write-Output "============================================================="

Restore-SqlAzureDatabase -databaseServerName $SQLAzureServerName `
    -databaseName $databaseName `
    -edition $SQLAzureDatabaseEdition `
    -serviceObjectiveName $SQLAzureServiceObjective `
    -storageName $AzureStorageAccountName `
    -containerName $AzureStorageContainerName `
    -sqlAdminUser $SqlAzureAdminUser `
    -sqlAdminPassword $SqlAzureAdminUserPassword `
    -bacpacFileName $BacPacFileName `
    -errorIfDatabaseExists $false
