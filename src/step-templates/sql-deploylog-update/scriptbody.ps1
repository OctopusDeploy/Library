<#
Required variables:
$DLM_PackageStep
$DLM_DeployStep
$DLM_ServerInstance
$DLM_Database

Optional variables (include for SQL Auth, exclude for WinAuth):
$DLM_Username
$DLM_Password
#>

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
$octo_release_number = $OctopusParameters["Octopus.Release.Number"]
$octo_deployment_id = $OctopusParameters["Octopus.Deployment.Id"]
$octo_deployment_created_by = $OctopusParameters["Octopus.Deployment.CreatedBy.Username"]
$deployStatusCode = $OctopusParameters["Octopus.Step[$DLM_DeployStep].Status.Code"]
$deployStatusError = $OctopusParameters["Octopus.Step[$DLM_DeployStep].Status.Error"]
$deployStatusErrorDetail = $OctopusParameters["Octopus.Step[$DLM_DeployStep].Status.ErrorDetail"]
$timestamp = Get-Date
$utcTime = [datetime]::Now.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# Escaping single quotes to avoid breaking T-SQL INSERT statements
$deployStatusError = $deployStatusError -replace "'", "''"
$deployStatusErrorDetail = $deployStatusErrorDetail -replace "'", "''"

# Logging input variables
Write-Verbose "DLM_PackageStep step is: $DLM_PackageStep"
Write-Verbose "DLM_DeployStep step is: $DLM_DeployStep"
Write-Verbose "DLM_ServerInstance instance is: $DLM_ServerInstance"
Write-Verbose "DLM_Database is: $DLM_Database"
Write-Verbose "DLM_Username is: $DLM_Username"
Write-Verbose "deployed_by is: $deployed_by"
Write-Verbose "currentPackageVersion is: $currentPackageVersion"
Write-Verbose "octo_release_number is: $octo_release_number"
Write-Verbose "octo_deployment_id is: $octo_deployment_id"
Write-Verbose "octo_deployment_created_by is: $octo_deployment_created_by"
Write-Verbose "deployStatusCode is: $deployStatusCode"
Write-Verbose "deployStatusError is: $deployStatusError"
Write-Verbose "deployStatusErrorDetail is: $deployStatusErrorDetail"
Write-Verbose "utcTime is: $utcTime"

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

# Script to create the __DeployLog table if it does not already exist
$CreateDeployLogTbl = @'
CREATE TABLE [dbo].[__DeployLog](
	[deploy_id] [int] IDENTITY(1,1) PRIMARY KEY,
	[package_version] [varchar](255) NOT NULL,
 	[octo_release_number] [nvarchar](50) NOT NULL,
   	[octo_deployment_id] [nvarchar](50) NOT NULL,
    [octo_deployment_created_by] [nvarchar](255) NOT NULL,
	[utc_time] [datetime2](7) NOT NULL,
	[deployed_by] [nvarchar](50) NULL,
    [status_code] [nvarchar](50) NULL,
    [status_error] [nvarchar](MAX) NULL,
    [status_error_detail] [nvarchar](MAX) NULL
    )
GO
'@

# Checking if __DeployLog still exists following deployment 
# (it may have been dropped if it wasn't included in source code)
$DeployLogExists = Invoke-Sqlcmd -ServerInstance $DLM_ServerInstance -Database $DLM_Database -Query $CheckDeployLogExists @Auth
$DeployLogExists = $DeployLogExists[0]

# If __DeployLog has been dropped, recreate it
if($DeployLogExists -eq "FALSE") {
    Write-Warning "Table __DeployLog does not exist in $DLM_Database on $DLM_ServerInstance post-deployment. It may have been deleted. You should either add the table to your source code or your filter to avoid data loss."
    Write-Output "Redeploying __DeployLog table"
    Invoke-Sqlcmd -ServerInstance $DLM_ServerInstance -Database $DLM_Database -Query $CreateDeployLogTbl @Auth
}

# Script to update __DeployLog with info about this deployment
$updateDeployLog = @"
INSERT INTO [dbo].[__DeployLog]
           ([package_version]
           ,[octo_release_number]
           ,[octo_deployment_id]
           ,[octo_deployment_created_by]
           ,[utc_time]
           ,[deployed_by]
           ,[status_code]
           ,[status_error]
           ,[status_error_detail])
     VALUES
           ('$currentPackageVersion'
           ,'$octo_release_number'
           ,'$octo_deployment_id'
           ,'$octo_deployment_created_by'
           ,'$utcTime'
           ,'$deployed_by'
           ,'$deployStatusCode'
           ,'$deployStatusError'
           ,'$deployStatusErrorDetail')
GO
"@

Write-Output "Updating __DeployLog in $DLM_Database on $DLM_ServerInstance."
Invoke-Sqlcmd -ServerInstance $DLM_ServerInstance -Database $DLM_Database -Query $updateDeployLog @Auth