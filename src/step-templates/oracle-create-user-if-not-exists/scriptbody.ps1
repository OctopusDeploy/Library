# Define variables
$connectionName = "OctopusDeploy"

# Define functions
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

function Install-PowerShellModule
{
    # Define parameters
    param(
        $PowerShellModuleName,
        $LocalModulesPath
    )

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

function Get-NugetPackageProviderNotInstalled
{
	# See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

function Get-UserExists
{
	# Define parameters
    param ($Hostname,
    $Username)
    
	# Execute query
    return Invoke-SqlQuery "SELECT * FROM ALL_USERS WHERE USERNAME = '$UserName'" -ConnectionName $connectionName
}

# Define PowerShell Modules path
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules$([System.IO.Path]::PathSeparator)$env:PSModulePath"
$PowerShellModuleName = "SimplySql"

# Set secure protocols
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

# Check to see if SimplySql module is installed
if ((Get-ModuleInstalled -PowerShellModuleName $PowerShellModuleName) -ne $true)
{
    # Tell user what we're doing
    Write-Output "PowerShell module $PowerShellModuleName is not installed, downloading temporary copy ..."

    # Install temporary copy
    Install-PowerShellModule -PowerShellModuleName $PowerShellModuleName -LocalModulesPath $LocalModules
}

# Display
Write-Output "Importing module $PowerShellModuleName ..."

# Check to see if it was downloaded
if ((Test-Path -Path "$LocalModules\$PowerShellModuleName") -eq $true)
{
	# Use specific location
    $PowerShellModuleName = "$LocalModules\$PowerShellModuleName"
}

# Import the module
Import-Module -Name $PowerShellModuleName

# Create credential object for the connection
$SecurePassword = ConvertTo-SecureString $oracleLoginPasswordWithAddUserRights -AsPlainText -Force
$ServerCredential = New-Object System.Management.Automation.PSCredential ($oracleLoginWithAddUserRights, $SecurePassword)

try
{
	# Connect to MySQL
    Open-OracleConnection -Datasource $oracleDBServerName -Credential $ServerCredential -Port $oracleDBServerPort -ServiceName $oracleServiceName -ConnectionName $connectionName

    # See if database exists
    $userExists = Get-UserExists -Username $oracleNewUsername

    if ($userExists -eq $null)
    {
        # Create database
        Write-Output "Creating user $oracleNewUsername ..."
        $executionResults = Invoke-SqlUpdate "CREATE USER `"$oracleNewUsername`" IDENTIFIED BY `"$oracleNewUserPassword`"" -ConnectionName $connectionName

        # See if it was created
        $userExists = Get-UserExists -Username $oracleNewUsername
            
        # Check array
        if ($userExists -ne $null)
        {
            # Success
            Write-Output "$oracleNewUsername created successfully!"
        }
        else
        {
            # Failed
            Write-Error "$oracleNewUsername was not created!"
        }
    }
    else
    {
    	# Display message
        Write-Output "User $oracleNewUsername already exists."
    }
}
finally 
{
	# Close connection if open
    if ((Test-SqlConnection -ConnectionName $connectionName) -eq $true)
    {
    	Close-SqlConnection -ConnectionName $connectionName
    }
}

