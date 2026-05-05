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

function Get-UserInRole
{
	# Define parameters
    param ($UserHostname,
    $Username,
    $RoleHostName,
    $RoleName)
    
	# Execute query
    $grants = Invoke-SqlQuery "SHOW GRANTS FOR '$Username'@'$UserHostName';" -ConnectionName $connectionName

    # Loop through Grants
    foreach ($grant in $grants.ItemArray)
    {
        # Check grant
        if ($grant -eq "GRANT $RoleName TO '$Username'@'$UserHostName'")
        {
            # They're in the group
            return $true
        }
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

# Declare initial connection string
$connectionString = "Server=$addMariaDBServerName;Port=$addMariaDBServerPort;"

# Update the connection string based on authentication method
switch ($mariaDbAuthenticationMethod) {
    "awsiam" {
        # Region is part of the RDS endpoint, extract
        $region = ($addMariaDBServerName.Split("."))[2]

        Write-Host "Generating AWS IAM token ..."
        $addLoginPasswordWithAddRoleRights = (aws rds generate-db-auth-token --hostname $addMariaDBServerName --region $region --port $addMariaDBServerPort --username $addLoginWithAddRoleRights)
        
        # Append remaining portion of connection string
        $connectionString += ";Uid=$addLoginWithAddRoleRights;Pwd=`"$addLoginPasswordWithAddRoleRights`";"

        break
    }
    "usernamepassword" {
        # Append remaining portion of connection string
        $connectionString += ";Uid=$addLoginWithAddRoleRights;Pwd=`"$addLoginPasswordWithAddRoleRights`";"
        
        break    
    }
    "windowsauthentication" {
        # Append remaining portion of connection string
        $connectionString += ";IntegratedSecurity=yes;Uid=$addLoginWithAddRoleRights;"

        break
    }
}

# Import the module
Import-Module -Name $PowerShellModuleName

try
{
    # Connect to MySQL
    Open-MySqlConnection -ConnectionString $connectionString -ConnectionName $connectionName

    # See if database exists
    $userInRole = Get-UserInRole -UserHostname $addUserHostname -Username $addUsername -RoleName $addRoleName

    if ($userInRole -eq $false)
    {
        # Create database
        Write-Output "Adding user $addUsername@$addUserHostName to role $addRoleName ..."
        $executionResults = Invoke-SqlUpdate "GRANT $addRoleName TO '$addUsername'@'$addUserHostName';" -ConnectionName $connectionName

        # See if it was created
        $userInRole = Get-UserInRole -UserHostname $addUserHostname -Username $addUsername -RoleName $addRoleName
            
        # Check array
        if ($userInRole -eq $true)
        {
            # Success
            Write-Output "$addUserName@$addUserHostName added to $addRoleName successfully!"
        }
        else
        {
            # Failed
            Write-Error "Failure adding $addUserName@$addUserHostName to $addRoleName!"
        }
    }
    else
    {
    	# Display message
        Write-Output "User $addUsername@$addUserHostName is already in role $addRoleName"
    }
}
finally
{
    if ((Test-Connection -ConnectionName $connectionName) -eq $true)
    {
      Close-SqlConnection -ConnectionName $connectionName
    }
}


