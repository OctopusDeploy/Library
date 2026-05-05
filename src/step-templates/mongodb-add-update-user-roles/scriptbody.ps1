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

    $moduleParameters = @{
      Name = $PowerShellModuleName
      Path = $LocalModulesPath
      Force = $true
    }

    # Check the version of PowerShell
    if ($PSVersionTable.PSVersion.Major -lt 7)
    {
      # Add specific version of powershell module to use
      $moduleParameters.Add("MaximumVersion", "6.7.4")
    }

	# Save the module in the temporary location
    Save-Module @moduleParameters
}

function Get-NugetPackageProviderNotInstalled
{
	# See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

function Get-DatabaseUserExists
{
	# Define parameters
    param ($UserName)
    
    # Define working variables
    $userExists = $false
    
	# Get users for database
    $command = @"
{ usersInfo: 1 }
"@

	$results = Invoke-MdbcCommand -Command $command
    $users = $results["users"]
    
    # Loop through returned results
    foreach ($user in $users)
    {
    	if ($user["user"] -eq $UserName)
        {
        	return $true
        }
    }
    
    return $false
}

# Define PowerShell Modules path
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules$([System.IO.Path]::PathSeparator)$env:PSModulePath"
$PowerShellModuleName = "Mdbc"

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

# Connect to mongodb instance
$connectionUrl = "mongodb://$($MongoDBAdminUsername):$($MogoDBAdminUserpassword)@$($MongoDBServerName):$($MongoDBPort)"

# Connect to MongoDB server
Connect-Mdbc $connectionUrl $MongoDBDatabaseName

# Get whether the database exits
if ((Get-DatabaseUserExists -UserName $MongoDBUsername) -eq $true)
{
	# Create user
    Write-Output "Adding $MongoDBRoles to $MongoDBUsername."
    
    # Create Roles array for adding
    $roles = @()
    foreach ($MongoDBRole in $MongoDBRoles.Split(","))
    {
    	$roles += @{
        	role = $MongoDBRole.Trim()
            db = $MongoDBDatabaseName
        }
    }

    # Define create user command
    $command = @"
{
	updateUser: `"$MongoDBUsername`"    
    roles: $(ConvertTo-Json $roles)
}
"@

	# Create user account
    $result = Invoke-MdbcCommand -Command $command
    
    # Check to make sure it was created successfully
    if ($result.ContainsKey("ok"))
    {
    	Write-Output "Successfully added role(s) $MongoDBRoles to $MongoDBUsername in database $MongoDBDatabaseName."
    }
    else
    {
    	Write-Error "Failed, $result"
    }
}
else
{
	Write-Error "Unable to add role(s) to $MongoDBUsername, user does not exist in $MongoDBDatabaseName."
}






