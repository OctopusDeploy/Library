$rgname = $OctopusParameters["azDbImport.rgName"]
$svrName = $OctopusParameters["azDbImport.sqlSvrName"]
$dbName = $OctopusParameters["azDbImport.dbName"]
$adminName = $OctopusParameters["azDbImport.adminName"]
$adminPwd = $OctopusParameters["azDbImport.adminPwd"]
$accessKey = $OctopusParameters["azDbImport.blobAccessKey"]
$accessKeyType = $OctopusParameters["azDbImport.accessKeyType"]
$containerUri = $OctopusParameters["azDbImport.ContainerUri"]
$backupName = $OctopusParameters["azDbImport.backupName"]

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

write-host "starting db import"
az sql db import --resource-group $rgname --server $svrName --name $dbName --admin-password $adminPwd --admin-user $adminName --storage-key $accessKey --storage-key-type $accessKeyType --storage-uri $backupUri
