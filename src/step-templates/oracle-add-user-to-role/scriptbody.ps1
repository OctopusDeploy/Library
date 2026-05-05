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

function Get-UserInRole
{
	# Define parameters
    param (
    $Username,
    $RoleName)
    
	# Execute query
    $userRole = Invoke-SqlQuery "SELECT * FROM DBA_ROLE_PRIVS WHERE GRANTEE = '$Username' AND GRANTED_ROLE = '$RoleName'"

    # Check to see if anything was returned
    if ($userRole.ItemArray.Count -gt 0)
    {
        # Found
        return $true
    }
    

    # Not found
    return $false
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
$SecurePassword = ConvertTo-SecureString $oracleLoginPasswordWithAddRoleRights -AsPlainText -Force
$ServerCredential = New-Object System.Management.Automation.PSCredential ($oracleLoginWithAddRoleRights, $SecurePassword)

try
{
	# Connect to MySQL
    Open-OracleConnection -Datasource $oracleServerName -Credential $ServerCredential -Port $oracleServerPort -ServiceName $oracleServiceName

    # See if database exists
    $userInRole = Get-UserInRole -Username $oracleUsername -RoleName $oracleRoleName

    if ($userInRole -eq $false)
    {
        # Create database
        Write-Output "Adding user $oracleUsername to role $oracleRoleName ..."
        $executionResults = Invoke-SqlUpdate "GRANT `"$oracleRoleName`" TO `"$oracleUsername`""

        # See if it was created
        $userInRole = Get-UserInRole -Username $oracleUsername -RoleName $oracleRoleName
            
        # Check array
        if ($userInRole -eq $true)
        {
            # Success
            Write-Output "$oracleUserName added to $oracleRoleName successfully!"
        }
        else
        {
            # Failed
            Write-Error "Failure adding $oracleUserName to $oracleRoleName!"
        }
    }
    else
    {
    	# Display message
        Write-Output "User $oracleUsername is already in role $oracleRoleName"
    }
}
finally
{
    Close-SqlConnection
}


