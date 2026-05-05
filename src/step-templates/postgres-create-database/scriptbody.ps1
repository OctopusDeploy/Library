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

function Get-DatabaseExists
{
	# Define parameters
    param ($DatabaseName)
    
	# Execute query
    return Invoke-SqlQuery -Query "SELECT datname FROM pg_catalog.pg_database where datname = '$DatabaseName';" -CommandTimeout $postgresCommandTimeout -ConnectionName $connectionName
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
	# Use specific version
    $PowerShellModuleName = "$LocalModules\$PowerShellModuleName"
}

# Import the module
Import-Module -Name $PowerShellModuleName

# Get whether trust certificate is necessary
$createTrustSSL = [System.Convert]::ToBoolean("$createTrustSSL")

try
{
	# Declare initial connection string
    $connectionString = "Server=$createPosgreSQLServerName;Port=$createPort;Database=postgres;"
    
	# Check to see if we need to trust the ssl cert
	if ($createTrustSSL -eq $true)
	{
        # Append SSL connection string components
        $connectionString += "SSL Mode=Require;Trust Server Certificate=true;"
	}

    # Update the connection string based on authentication method
    switch ($postgreSqlAuthenticationMethod)
    {
        "azuremanagedidentity"
        {
        	# Get login token
            Write-Host "Generating Azure Managed Identity token ..."
            $token = Invoke-RestMethod -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://ossrdbms-aad.database.windows.net" -Headers @{"MetaData" = "true"}
            
            # Append remaining portion of connection string
            $connectionString += ";User Id=$createUsername;Password=`"$($token.access_token)`";"
            
            break
        }
        "awsiam"
        {
            # Region is part of the RDS endpoint, extract
            $region = ($createPosgreSQLServerName.Split("."))[2]

            Write-Host "Generating AWS IAM token ..."
            $createUserPassword = (aws rds generate-db-auth-token --hostname $createPosgreSQLServerName --region $region --port $createPort --username $createUsername)

            # Append remaining portion of connection string
            $connectionString += ";User Id=$createUsername;Password=`"$createUserPassword`";"

            break
        }
        "gcpserviceaccount"
        {
            # Define header
            $header = @{ "Metadata-Flavor" = "Google"}

            # Retrieve service accounts
            $serviceAccounts = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" -Headers $header

            # Results returned in plain text format, get into array and remove empty entries
            $serviceAccounts = $serviceAccounts.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

            # Retreive the specific service account assigned to the VM
            $serviceAccount = $serviceAccounts | Where-Object {$_.Contains("iam.gserviceaccount.com") }

            Write-Host "Generating GCP IAM token ..."
            # Retrieve token for account
            $token = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/$serviceAccount/token" -Headers $header
            
            # Check to see if there was a username provided
            if ([string]::IsNullOrWhitespace($createUsername))
            {
            	# Use the service account name, but strip off the .gserviceaccount.com part
                $createUsername = $serviceAccount.SubString(0, $serviceAccount.IndexOf(".gserviceaccount.com"))
            }
  
            # Append remaining portion of connection string
            $connectionString += ";User Id=$createUsername;Password=`"$($token.access_token)`";"
  
            break
        }
        "usernamepassword"
        {
            # Append remaining portion of connection string
            $connectionString += ";User Id=$createUsername;Password=`"$createUserPassword`";"

            break    
        }

        "windowsauthentication"
        {
            # Append remaining portion of connection string
            $connectionString += ";Integrated Security=True;"
        }
    }

	# Open connection
    Open-PostGreConnection -ConnectionString $connectionString -ConnectionName $connectionName

    # See if database exists
    $databaseExists = Get-DatabaseExists -DatabaseName $createDatabaseName

    if ($databaseExists.ItemArray.Count -eq 0)
    {
        # Create database
        Write-Output "Creating database $createDatabaseName ..."
        $executionResult = Invoke-SqlUpdate -Query "CREATE DATABASE `"$createDatabaseName`";" -CommandTimeout $postgresCommandTimeout -ConnectionName $connectionName

        # Check result
        if ($executionResult -ne -1)
        {
            # Commit transaction
            Write-Error "Create schema failed."
        }
        else
        {
        	# See if it was created
            $databaseExists = Get-DatabaseExists -DatabaseName $createDatabaseName
            
            # Check array
            if ($databaseExists.ItemArray.Count -eq 1)
            {
            	# Success
                Write-Output "$createDatabaseName created successfully!"
            }
            else
            {
            	# Failed
                Write-Error "$createDatabaseName was not created!"
            }
        }
    }
    else
    {
    	# Display message
        Write-Output "Database $createDatabaseName already exists."
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


