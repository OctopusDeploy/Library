$rgname = $OctopusParameters["azDbExport.rgName"]
$svrName = $OctopusParameters["azDbExport.sqlSvrName"]
$dbName = $OctopusParameters["azDbExport.dbName"]
$adminName = $OctopusParameters["azDbExport.adminName"]
$adminPwd = $OctopusParameters["azDbExport.adminPwd"]
$accessKey = $OctopusParameters["azDbExport.blobAccessKey"]
$accessKeyType = $OctopusParameters["azDbExport.accessKeyType"]
$containerUri = $OctopusParameters["azDbExport.ContainerUri"]
$backupName = $OctopusParameters["azDbExport.backupName"]

$backupUri = "$containerUri/$backupName.bacpac"

if([string]::IsNullOrEmpty($rgname))
{
	throw "resource group name is not provided"
}

if([string]::IsNullOrEmpty($svrName))
{
	throw "sql server name is not provided"
}

if([string]::IsNullOrEmpty($dbName))
{
	throw "database name not provided"
}
# admin name, password and access key will not be validated in favor of security

if([string]::IsNullOrEmpty($accessKeyType))
{
	throw "access key type not provided"
}

if([string]::IsNullOrEmpty($containerUri))
{
	throw "containerUri not provided"
}

if([string]::IsNullOrEmpty($backupName))
{
	throw "backup name not provided"
}

write-host "starting db export"
az sql db export --resource-group $rgname --server $svrName --name $dbName --admin-password $adminPwd --admin-user $adminName --storage-key $accessKey --storage-key-type $accessKeyType --storage-uri $backupUri
