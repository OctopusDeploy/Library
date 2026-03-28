if($IsEnabled -eq "True")
{
Write-Output "Starting Backup the Azure table 'https://$sourceStorageAccountName.table.core.windows.net/$sourceTableName' to the Blob 'https://$destinationStorageAccountName.blob.core.windows.net/$sourceStorageAccountName-$sourceTableName'"

& "${Env:ProgramFiles(x86)}\Microsoft SDKs\Azure\AzCopy\azCopy.exe" `
    /Source:https://$sourceStorageAccountName.table.core.windows.net/$sourceTableName/ `
    /Dest:https://$destinationStorageAccountName.blob.core.windows.net/$sourceStorageAccountName-$sourceTableName/ `
    /SourceKey:$sourceStorageAccountKey `
    /Destkey:$destinationStorageAccountKey `
    /y

Write-Output "Backup Completed"
}
else
{
    Write-Output "This Step is disabled"
}