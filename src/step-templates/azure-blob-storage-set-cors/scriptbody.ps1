try
{ 
    Import-Module Azure -ErrorAction Stop
}
catch
{
    throw "Windows Azure Powershell not found! Please make sure to install them from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
}

Import-AzurePublishSettingsFile $PublishSettingsFile

$context = New-AzureStorageContext `
    -StorageAccountName $StorageAccount `
    -StorageAccountKey $StorageAccountKey

$container = Get-AzureStorageContainer -Context $context | 
        Where-Object { $_.Name -like $StorageContainer }

if (-not $container)
{
    throw "Azure storage container ($StorageAccount) not found"
}

$corsRules = (@{
    AllowedHeaders=@($AllowedHeaders);
    AllowedOrigins=@($AllowedOrigins);
    MaxAgeInSeconds=$MaxAgeInSeconds;
    AllowedMethods=@($AllowedMethods)})

Set-AzureStorageCORSRule -Context $context -ServiceType Blob -CorsRules $corsRules

Write-Host "Added CORS rule to container: $StorageContainer"