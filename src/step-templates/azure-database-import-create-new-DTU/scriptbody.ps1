#get variables into easy to use format
# Create DB Variables
$databaseName = $OctopusParameters["azDbImportNewDTU.dbName"]
$sqlServer = $OctopusParameters["azDbImportNewDTU.server"]
$rgName = $OctopusParameters["azDbImportNewDTU.resourceGroup"]
$elasticPool = $OctopusParameters["azDbImportNewDTU.elasticPool"]
$readScaleTruthy = $OctopusParameters["azDbImportNewDTU.readScale"]
$serviceObjective = $OctopusParameters["azDbImportNewDTU.serviceObjective"]
$tags = $OctopusParameters["azDbImportNewDTU.tags"]
$zoneRedundant = $OctopusParameters["azDbImportNewDTU.zoneRedundant"]
$maxSize = $OctopusParameters["azDbImportNewDTU.maxSize"]

# Import bacpac variables
$adminName = $OctopusParameters["azDbImportNewDTU.adminName"]
$adminPwd = $OctopusParameters["azDbImportNewDTU.adminPwd"]
$accessKey = $OctopusParameters["azDbImportNewDTU.blobAccessKey"]
$accessKeyType = $OctopusParameters["azDbImportNewDTU.accessKeyType"]
$containerUri = $OctopusParameters["azDbImportNewDTU.ContainerUri"]
$backupName = $OctopusParameters["azDbImportNewDTU.backupName"]
$backupUri = "$containerUri/$backupName.bacpac"

$readScaleValue = "Disabled"

if($readScaleTruthy -eq "true") { $readScalevalue = "Enabled" }

$ServiceObjectiveSizes = @{Basic = 2GB; S0 = 250GB; S1 = 250GB; S2 = 250GB; S3 = 1TB; S4 = 1TB; S6 = 1TB; S7 = 1TB; S9 = 1TB; S12 = 1TB; P1 = 1TB; P2 = 1TB; P4 = 1TB; P6 = 1TB; P11 = 4TB; P15 = 4TB}

if($null -eq (az sql server list --query "[?Name==$sqlServer]" | ConvertFrom-Json))
{
    throw "$sqlServer doesn't exist or the selected azure account doesn't have access to it."
}

if($null -ne (az sql db list --resource-group $rgName --server $sqlServer --query "[?Name==$databaseName]" | ConvertFrom-Json))
{
    throw "$databaseName already exists"
}

#validate parameters

if(($maxSize / 1GB) -gt ($ServiceObjectiveSizes[$serviceObjective] / 1GB))
{
    Write-Warning "Desired max size of $($maxSize / 1GB)GB exceeds max size of $($ServiceObjectiveSizes[$serviceObjective] / 1GB)GB for selected service objective: $serviceObjective"
    Write-Warning "Setting max size to $($ServiceObjectiveSizes[$serviceObjective] / 1GB)GB"
    $maxSize = "$($ServiceObjectiveSizes[$serviceObjective] / 1GB)GB"
}

if([string]::IsNullOrEmpty($rgname))
{
	throw "resource group name is not provided"
}

if([string]::IsNullOrEmpty($sqlServer))
{
	throw "sql server name is not provided"
}

if([string]::IsNullOrEmpty($databaseName))
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

# validate premium SKU settings
if(!$serviceObjective.Contains('P'))
{
    if($readScaleValue -eq "Enabled")
    {
        Write-Warning "Read Scaling only available for premium SKUs. Setting database read scale to disabled"
        $readScaleValue = "Disabled"
    }
    if($zoneRedundant -eq "true")
    {
        Write-Warning "Zone redundant only available for premium SKUs. Setting database zone redundant to false"
        $zoneRedundant = "false"
    }
}

$cliArgs = "--name $databaseName --resource-group $rgName --server $sqlServer"

if($elasticPool) {$cliArgs += " --elastic-pool $elasticPool"}
else {$cliArgs += " --max-size $maxSize --service-objective $serviceObjective  --zone-redundant $zoneRedundant"}

if($tags) {$cliArgs += " --tags $tags"}
if($readScale) {$cliArgs += " --read-scale $readScaleValue"}


$cmd = "az sql db create $cliArgs"

write-verbose "cmd is: $cmd"

Write-Host "Creating Database"
Invoke-Expression $cmd

write-host "starting db import"
write-verbose "import cmd az sql db import --resource-group $rgname --server $sqlServer --name $databaseName --admin-password $adminPwd --admin-user $adminName --storage-key $accessKey --storage-key-type $accessKeyType --storage-uri $backupUri"

az sql db import --resource-group $rgname --server $sqlServer --name $databaseName --admin-password $adminPwd --admin-user $adminName --storage-key $accessKey --storage-key-type $accessKeyType --storage-uri $backupUri
