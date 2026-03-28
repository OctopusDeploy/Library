function Get-ModuleInstalled
{
    # Define parameters
    param(
        $PowerShellModuleName
    )

    # Check to see if the module is installed
    if ($null -ne (Get-Module -ListAvailable -Name $PowerShellModuleName))
    {
        # It is installed
        return $true
    }
    else
    {
        # Module not installed
        return $false
    }
}

function Get-NugetPackageProviderNotInstalled
{
	# See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

function Install-PowerShellModule
{
    # Define parameters
    param(
        $PowerShellModuleName,
        $LocalModulesPath
    )
    
    # Set TLS order
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

	# Check to see if the package provider has been installed
    if ((Get-NugetPackageProviderNotInstalled) -ne $false)
    {
    	# Display that we need the nuget package provider
        Write-Host "Nuget package provider not found, installing ..."
        
        # Install Nuget package provider
        Install-PackageProvider -Name Nuget -Force
    }

	# Save the module in the temporary location
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force

}

# Define PowerShell Modules path
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules;$env:PSModulePath"

# Check to see if SqlServer module is installed
if (((Get-ModuleInstalled -PowerShellModuleName "SqlServer") -ne $true) -and ((Get-ModuleInstalled -PowerShellModuleName "SQLPS") -ne $true))
{
  # Display message
  Write-Output "PowerShell module SqlServer not present, downloading temporary copy ..."

  # Download and install temporary copy
  Install-PowerShellModule -PowerShellModuleName "SqlServer" -LocalModulesPath $LocalModules
  
  # Display
  Write-Output "Importing module SqlServer ..."

  # Import the module
  Import-Module -Name "SqlServer"  
}

Write-Host "SqlLoginWhoHasRights $autoFixSqlLoginUserWhoHasRights"
Write-Host "SqlServer $autoFixSqlServer"
Write-Host "DatabaseName $autoFixDatabaseName"
Write-Host "SqlLogin $autoFixSqlLogin"

if ([string]::IsNullOrWhiteSpace($autoFixSqlLoginUserWhoHasRights) -eq $true){
	Write-Host "No username found, using integrated security"
    $connectionString = "Server=$autoFixSqlServer;Database=$autoFixDatabaseName;integrated security=true;"
}
else {
	Write-Host "Username found, using SQL Authentication"
    $connectionString = "Server=$autoFixSqlServer;Database=$autoFixDatabaseName;User ID=$autoFixSqlLoginUserWhoHasRights;Password=$autoFixSqlLoginPasswordWhoHasRights;"
}

# Build sql query
$sqlQuery = @"
DECLARE @OrphanedUsers TABLE
(
	UserName VARCHAR(50) null,
	UserSID VARBINARY(100) null
)

INSERT INTO @OrphanedUsers EXEC sp_change_users_login 'Report'

IF EXISTS ( SELECT UserName FROM @OrphanedUsers WHERE UserName = '$autoFixSqlLogin' )
	BEGIN
		PRINT '$autoFixSqlLogin is orphaned, fixing ...'
        EXEC sp_change_users_login 'Auto_Fix', '$autoFixSqlLogin'
    END
ELSE
	PRINT '$autoFixSqlLogin is not orphaned.'
"@

# Execute the command to find orphaned users, then fix if matching
Invoke-SqlCmd -ConnectionString $connectionString -Query $sqlQuery -Verbose

