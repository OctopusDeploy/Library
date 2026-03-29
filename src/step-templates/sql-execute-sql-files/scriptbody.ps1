
function Get-ModuleInstalled {
    # Define parameters
    param(
        $PowerShellModuleName
    )

    # Check to see if the module is installed
    if ($null -ne (Get-Module -ListAvailable -Name $PowerShellModuleName)) {
        # It is installed
        return $true
    }
    else {
        # Module not installed
        return $false 
    }
}

function Get-NugetPackageProviderNotInstalled {
    # See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

function Install-PowerShellModule {
    # Define parameters
    param(
        $PowerShellModuleName,
        $LocalModulesPath
    )
    
    # Set TLS order
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

    # Check to see if the package provider has been installed
    if ((Get-NugetPackageProviderNotInstalled) -ne $false) {
        # Display that we need the nuget package provider
        Write-Output "Nuget package provider not found, installing ..."
        
        # Install Nuget package provider
        Install-PackageProvider -Name Nuget -Force
    }

    # Save the module in the temporary location
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force
}


function Invoke-ExecuteSQLScript {

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $serverInstance,

        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $dbName,

        [string]
        $Authentication,

        [string]
        $SQLScripts,

        [bool]
        $DisplaySqlServerOutput,
        
        [bool]
        $TrustServerCertificate
    )
    
    # Check to see if SqlServer module is installed
    if ((Get-ModuleInstalled -PowerShellModuleName "SqlServer") -ne $true) {
        # Display message
        Write-Output "PowerShell module SqlServer not present, downloading temporary copy ..."

        # Download and install temporary copy
        Install-PowerShellModule -PowerShellModuleName "SqlServer" -LocalModulesPath $LocalModules
    }

    # Display
    Write-Output "Importing module SqlServer ..."

    # Import the module
    Import-Module -Name "SqlServer"
    
    $ExtractedPackageLocation = $($OctopusParameters['Octopus.Action.Package[template.Package].ExtractedPath'])

    $matchingScripts = @()

    # 1. Locate matching scripts
    foreach ($SQLScript in $SQLScripts.Split("`n", [System.StringSplitOptions]::RemoveEmptyEntries)) {
        try {
            
            Write-Verbose "Searching for scripts matching '$($SQLScript)'"
            $scripts = @()
            $parent = Split-Path -Path $SQLScript -Parent
            $leaf = Split-Path -Path $SQLScript -Leaf
            Write-Verbose "Parent: '$parent', Leaf: '$leaf'"
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                $path = Join-Path $ExtractedPackageLocation $parent
                if (Test-Path $path) {
                    Write-Verbose "Searching for items in '$path' matching '$leaf'"
                    $scripts += @(Get-ChildItem -Path $path -Filter $leaf)
                }
                else {
                    Write-Warning "Path '$path' not found. Please check the path exists, and is relative to the package contents."
                }
            }
            else {
                Write-Verbose "Searching in root of package for '$leaf'"
                $scripts += @(Get-ChildItem -Path $ExtractedPackageLocation -Filter $leaf)
            }
    
            Write-Output "Found $($scripts.Count) SQL scripts matching input '$SQLScript'"

            $matchingScripts += $scripts
        }
        catch {
            Write-Error $_.Exception
        }
    }
    
    # Create arguments hash table
    $sqlcmdArguments = @{}

	# Add bound parameters
    $sqlcmdArguments.Add("ServerInstance", $serverInstance)
    $sqlcmdArguments.Add("Database", $dbName)
    #$sqlcmdArguments.Add("Query", $SQLScripts)
    
    if ($DisplaySqlServerOutput)
    {
    	Write-Host "Adding Verbose to argument list to display output ..."
        $sqlcmdArguments.Add("Verbose", $DisplaySqlServerOutput)
    }
    
    if ($TrustServerCertificate)
    {
    	$sqlcmdArguments.Add("TrustServerCertificate", $TrustServerCertificate)
    }

    # Only execute if we have matching scripts
    if ($matchingScripts.Count -gt 0) {
        foreach ($script in $matchingScripts) {
            $sr = New-Object System.IO.StreamReader($script.FullName)
            $scriptContent = $sr.ReadToEnd()
        
            # Execute based on selected authentication method
            switch ($Authentication) {
                "AzureADManaged" {
                    # Get login token
                    Write-Verbose "Authenticating with Azure Managed Identity ..."
                
                    $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fdatabase.windows.net%2F' -Method GET -Headers @{Metadata = "true" } -UseBasicParsing
                    $content = $response.Content | ConvertFrom-Json
                    $AccessToken = $content.access_token
                    
                    $sqlcmdArguments.Add("AccessToken", $AccessToken)

                    break
                }
                "SqlAuthentication" {
                    Write-Verbose "Authentication with SQL Authentication ..."
                    $sqlcmdArguments.Add("Username", $username)
                    $sqlcmdArguments.Add("Password", $password)

                    break
                }
                "WindowsIntegrated" {
                    Write-Verbose "Authenticating with Windows Authentication ..."
                    break
                }
            }
            
            $sqlcmdArguments.Add("Query", $scriptContent)
            
            # Invoke sql cmd
            Invoke-SqlCmd @sqlcmdArguments
        
            $sr.Close()

            Write-Verbose ("Executed manual script - {0}" -f $script.Name)
        }
    }
}

# Define PowerShell Modules path
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules$([System.IO.Path]::PathSeparator)$env:PSModulePath"

if (Test-Path Variable:OctopusParameters) {
    Write-Verbose "Locating scripts from the literal entry of Octopus Parameter SQLScripts"
    $ScriptsToExecute = $OctopusParameters["SQLScripts"]
    $DisplaySqlServerOutput = $OctopusParameters["ExecuteSQL.DisplaySQLServerOutput"] -ieq "True"
    $TemplateTrustServerCertificate = [System.Convert]::ToBoolean($OctopusParameters["ExecuteSQL.TrustServerCertificate"])
    
    Invoke-ExecuteSQLScript -serverInstance $OctopusParameters["serverInstance"] `
        -dbName $OctopusParameters["dbName"] `
        -Authentication $OctopusParameters["Authentication"] `
        -SQLScripts $ScriptsToExecute `
        -DisplaySqlServerOutput $DisplaySqlServerOutput `
        -TrustServerCertificate $TemplateTrustServerCertificate
}