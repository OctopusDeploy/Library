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

function Get-DatabaseExists
{
	# Define parameters
    param ($DatabaseName)
    
	# Execute query
    $mongodbDatabases = Get-MdbcDatabase
    
    return $mongodbDatabases.DatabaseNamespace -contains $DatabaseName
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
$connectionUrl = "mongodb://$($MongoDBUsername):$($MogoDBUserpassword)@$($MongoDBServerName):$($MongoDBPort)"

# Connect to MongoDB server
Connect-Mdbc $connectionUrl "admin"

# Get whether the database exits
if ((Get-DatabaseExists -DatabaseName $MongoDBDatabaseName) -ne $true)
{
	# Create database
    Write-Output "Database $MongoDBDatabaseName doesn't exist."
    Connect-Mdbc $connectionUrl "$MongoDBDatabaseName"
    
    # Databases don't get created unless some data has been added
    Add-MdbcCollection $MongoDBInitialCollection
    
    # Check to make sure it was successful
    if ((Get-DatabaseExists -DatabaseName $MongoDBDatabaseName))
    {
    	# Display success
        Write-Output "$MongoDBDatabaseName created successfully."        
    }
    else
    {
    	Write-Error "Failed to create $MongoDBDatabaseName!"
    }
}
else
{
	Write-Output "Database $MongoDBDatabaseName already exists."
}






