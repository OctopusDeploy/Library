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
        # Module not installed -ConnectionName $connectionName
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
$postgresqlTrustSSL = [System.Convert]::ToBoolean("$postgresqlTrustSSL")

try
{
	# Declare initial connection string
    $connectionString = "Server=$postgresqlServerName;Port=$postgresqlServerPort;Database=$postgresqlDatabaseName;"
    
	# Check to see if we need to trust the ssl cert
	if ($postgresqlTrustSSL -eq $true)
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
            $connectionString += ";User Id=$postgresqlUsername;Password=`"$($token.access_token)`";"
            
            break
        }
        "awsiam"
        {
            # Region is part of the RDS endpoint, extract
            $region = ($createPosgreSQLServerName.Split("."))[2]

            Write-Host "Generating AWS IAM token ..."
            $createUserPassword = (aws rds generate-db-auth-token --hostname $postgresqlServerName --region $region --port $createPort --username $postgresqlUsername)

            # Append remaining portion of connection string
            $connectionString += ";User Id=$postgresqlUsername;Password=`"$postgesqlUserPassword`";"

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
            if ([string]::IsNullOrWhitespace($postgresqlUsername))
            {
            	# Use the service account name, but strip off the .gserviceaccount.com part
                $postgresqlUsername = $serviceAccount.SubString(0, $serviceAccount.IndexOf(".gserviceaccount.com"))
            }
  
            # Append remaining portion of connection string
            $connectionString += ";User Id=$postgresqlUsername;Password=`"$($token.access_token)`";"
  
            break
        }
        "usernamepassword"
        {
            # Append remaining portion of connection string
            $connectionString += ";User Id=$postgresqlUsername;Password=`"$postgesqlUserPassword`";"

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

    # Execute the statement
    $executionResult = Invoke-SqlUpdate -Query "$postgresqlCommand" -CommandTimeout $postgresqlCommandTimeout -ConnectionName $connectionName
    
    # Display the result
    Get-SqlMessage -ConnectionName $connectionName
}
finally
{
	# Close connection if open
    if ((Test-SqlConnection -ConnectionName $connectionName) -eq $true)
    {
    	Close-SqlConnection -ConnectionName $connectionName
    }
}


