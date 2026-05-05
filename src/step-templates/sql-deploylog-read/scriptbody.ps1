$errorActionPreference = "stop"

# Verifying that sqlserver module is installed
If (-not(Get-InstalledModule sqlserver -ErrorAction silentlycontinue)) {
  Write-Error "This step requires the sqlserver PowerShell module. Please install it and try again."
}
Else {
  Write-Output "PowerShell module sqlserver is already installed."
}

# Declaring variabes
$deployed_by = ([Environment]::UserDomainName + "\" + [Environment]::UserName)
$currentPackageVersion = $OctopusParameters["Octopus.Action[$DLM_PackageStep].Package.PackageVersion"]
$deployRequired = "False"

# Logging input variables
Write-Verbose "DLM_PackageStep step is: $DLM_PackageStep"
Write-Verbose "DLM_ServerInstance instance is: $DLM_ServerInstance"
Write-Verbose "DLM_Database is: $DLM_Database"
Write-Verbose "deployed_by is: $deployed_by"
Write-Verbose "currentPackageVersion is: $currentPackageVersion"

# For invoke-sqlcmd authentication
$auth=@{}
if($DLM_Username){$auth=@{UserName=$DLM_Username;Password=$DLM_Password}}

# Script to check whether __DeployLog exists in target database
$CheckDeployLogExists = @'
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES
           WHERE TABLE_NAME = N'__DeployLog')
    BEGIN
    SELECT 'TRUE'
    END 
ELSE
    BEGIN
    SELECT 'FALSE'
    End
'@

# Verifying whether _DeployLog exists
$DeployLogExists = Invoke-Sqlcmd -ServerInstance $DLM_ServerInstance -Database $DLM_Database -Query $CheckDeployLogExists @Auth 
$DeployLogExists = $DeployLogExists[0]
if($DeployLogExists -eq 'FALSE') {
    Write-Warning "Table __DeployLog does not exist in $DLM_Database on $DLM_ServerInstance pre-deployment."
}

# Script to read the last successful package version from __DeployLog
$getLastPackageVersion = @'
SELECT TOP (1) package_version 
FROM [dbo].[__DeployLog]
WHERE  status_code='Succeeded'
ORDER BY utc_time DESC
'@

# Condition 1: If there is no __DeployLog table we don't know the prior state so we need to deploy the package
if($DeployLogExists -eq 'FALSE') {
    Write-Output "There is no __DeployLog table on target database. Assuming re-deployment is required."
    $deployRequired = "True"}
else{
    # Condition 2: If the package version has changed we need to deploy the new package
    $lastPackageVersion = Invoke-Sqlcmd -ServerInstance $DLM_ServerInstance -Database $DLM_Database -Query $getLastPackageVersion @Auth
    try{
        $lastPackageVersion = $lastPackageVersion[0]
    }
    catch{
        Write-Warning "__DeployLog is empty"
        $lastPackageVersion = "NULL"
    }
    if($lastPackageVersion -ne $currentPackageVersion){
        Write-Output "Package version ($currentPackageVersion) differs from previous package version ($lastPackageVersion), re-deployment is required."
        $deployRequired = "True"
    }
}

# If neither condition 1 or 2 above are met, __DeployLog indicates that this 
# package has already been successfully deployed - so we can skip the deployment
if($deployRequired -like "False"){
    Write-Output "Skipping the deployment because the __DeployLog table in $DLM_Database on $DLM_ServerInstance indicates that package $currentPackageVersion has already been successfully deployed."
}

Set-OctopusVariable -name "Deploy:$DLM_ServerInstance-$DLM_Database" -value $deployRequired
