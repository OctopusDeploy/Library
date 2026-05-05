#get variables into easy to use format

# vCPU vars
$family = $OctopusParameters["azDbImportNewVCPU.family"] # Gen4 is being phased out.
$computeModel = $OctopusParameters["azDbImportNewVCPU.computeModel"]
$readReplicaCount = $OctopusParameters["azDbImportNewVCPU.readReplicaCount"]
$edition = $OctopusParameters["azDbImportNewVCPU.edition"]
$capacity = $OctopusParameters["azDbImportNewVCPU.coreCount"] -as [int]

# Create DB Variables
$databaseName = $OctopusParameters["azDbImportNewVCPU.dbName"]
$sqlServer = $OctopusParameters["azDbImportNewVCPU.server"]
$rgName = $OctopusParameters["azDbImportNewVCPU.resourceGroup"]
$elasticPool = $OctopusParameters["azDbImportNewVCPU.elasticPool"]
$readScaleTruthy = $OctopusParameters["azDbImportNewVCPU.readScale"]

$tags = $OctopusParameters["azDbImportNewVCPU.tags"]
$zoneRedundant = $OctopusParameters["azDbImportNewVCPU.zoneRedundant"]
$maxSize = $OctopusParameters["azDbImportNewVCPU.maxSize"]

# Import bacpac variables
$adminName = $OctopusParameters["azDbImportNewVCPU.adminName"]
$adminPwd = $OctopusParameters["azDbImportNewVCPU.adminPwd"]
$accessKey = $OctopusParameters["azDbImportNewVCPU.blobAccessKey"]
$accessKeyType = $OctopusParameters["azDbImportNewVCPU.accessKeyType"]
$containerUri = $OctopusParameters["azDbImportNewVCPU.ContainerUri"]
$backupName = $OctopusParameters["azDbImportNewVCPU.backupName"]
$backupUri = "$containerUri/$backupName.bacpac"

$readScaleValue = "Disabled"

if($readScaleTruthy -eq "true") { $readScalevalue = "Enabled" }
$maxAvailableSize = 1TB

$gen5VcpuCount = 2,4,6,8,10,12,14,16,18,20,24,32,40,80
$gen5VcpuCountSvrless = 1,2,4,6,8,10,12,14,16,18,20,24,32,40

#validate parameters

if($null -eq (az sql server list --query "[?Name==$sqlServer]" | ConvertFrom-Json))
{
    throw "$sqlServer doesn't exist or the selected azure account doesn't have access to it."
}

if($null -ne (az sql db list --resource-group $rgName --server $sqlServer --query "[?Name==$databaseName]" | ConvertFrom-Json))
{
    throw "$database already exists"
}

# max size for all databases (except GP serverless) is 1TB

if([string]::IsNullOrEmpty($rgName))
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

switch($edition)
{
    "GeneralPurpose"
    {
        switch($computeModel)
        {
            "Provisioned"
            {
                switch($family)
                {
                    "Gen5"
                    {
                    	write-verbose "Capacity set to: $capacity"
                        if($capacity -lt 2)
                        {
                        	Write-Warning "Minimum vCPU for provisioned is 2"
                            Write-Warning "setting vCPU to 2"
                            $capacity = 2
                        }
                        if(!$gen5VcpuCount.Contains($capacity))
                        {
                            throw "Invalid max vCPU count entered valid values for Gen5 hardware is: $gen5VcpuCount"
                        }
                        $maxAvailableSize = 1TB
                    }
                    "FSv2"
                    {
                        $capacity = 72
                        $maxAvailableSize = 4TB
                    }
                    "Default"
                    {
                        throw "Invalid hardware family selected for General purpose"
                    }
                }
            }
            "Serverless"
            {
                if($capacity -gt 40)
                {
                    Write-Warning "Max vCPUs for serverless is 40"
                    Write-Warning "Setting max vCPU to 40"
                    $capacity = 40
                }

                if($family -ne "Gen5") {throw "Only Gen5 hardware family available for serverless"}

                if(!$gen5VcpuCountSvrless.Contains($capacity))
                {
                    throw "Invalid max vCPU count entered valid values for serverless Gen5 hardware is: $gen5VcpuCountSvrless"
                }
                $maxAvailableSize = 512GB
            }
        }
    }
    "Hyperscale"
    {
        if($family -ne "Gen5") {throw "Only Gen5 hardware family available for Hyperscale"}

        if($capacity -lt 2)
        {
            Write-Warning "Minimum vCPU for provisioned is 2"
            Write-Warning "setting vCPU to 2"
            $capacity = 2
        }

        if(!$gen5VcpuCount.Contains($capacity))
        {
            throw "Invalid max vCPU count entered valid values for Gen5 hardware is: $gen5VcpuCount"
        }
    }
    "BusinessCritical"
    {
        switch ($family)
        {
            "Gen5"
            {
                if($capacity -lt 2)
                {
                    Write-Warning "Minimum vCPU for provisioned is 2"
                    Write-Warning "setting vCPU to 2"
                    $capacity = 2
                }

                if(!$gen5VcpuCount.Contains($capacity))
                {
                    throw "Invalid max vCPU count entered valid values for Gen5 hardware is: $gen5VcpuCount"
                }
                $maxAvailableSize = 1TB
            }
            "M"
            {
                $capacity = 128
                $maxAvailableSize = 4TB
                if($zoneRedundant -eq "true")
                {
                    Write-Warning "Zone redundant not available for M-Series hardware configuration"
                    Write-Warning "Setting zone redundant to false"
                    $zoneRedundant = "false"
                }
            }
        }
    }
}

if(($maxSize / 1GB) -gt ($maxAvailableSize / 1GB))
{
    Write-Warning "Desired max size of $($maxSize / 1GB)GB exceeds available max size of $($maxAvailableSize / 1GB)GB"
    Write-Warning "Setting max size to $($maxAvailableSize / 1GB)GB"
    $maxSize = $maxAvailableSize
}

$cliArgs = "--name $databaseName --resource-group $rgName --server $sqlServer"

if($elasticPool) {$cliArgs += " --elastic-pool $elasticPool"}
else {$cliArgs += " --edition $edition --family $family --capacity $capacity"}

if((!$edition -eq "Hyperscale") -and $maxSize) {$cliArgs += " --max-size $maxSize"}
if($edition -eq "GeneralPurpose") {$cliArgs += " --compute-model $computeModel"}
if($edition -eq "Hyperscale") {cliArgs += " --read-replicas $readReplicaCount"}
if($tags) {$cliArgs += " --tags $tags"}
if($edition -eq "BusinessCritical") {$cliArgs += " --read-scale $readScaleValue --zone-redundant $zoneRedundant"}
if($elasticPool) {$cliArgs += " --elastic-pool $elasticPool"}

$cmd = "az sql db create $cliArgs"

write-verbose "cmd is: $cmd"

Write-Host "Creating Database"
invoke-expression "$cmd"

write-host "starting db import"
write-verbose "import cmd az sql db import --resource-group $rgname --server $sqlServer --name $databaseName --admin-password $adminPwd --admin-user $adminName --storage-key $accessKey --storage-key-type $accessKeyType --storage-uri $backupUri"

az sql db import --resource-group $rgname --server $sqlServer --name $databaseName --admin-password $adminPwd --admin-user $adminName --storage-key $accessKey --storage-key-type $accessKeyType --storage-uri $backupUri
