#region Functions

# Define functions
function Get-SqlModuleInstalled
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

function Install-SqlServerPowerShellModule
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
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force -RequiredVersion "21.1.18256" 

	# Display
    Write-Output "Importing module $PowerShellModuleName ..."

    # Import the module
    Import-Module -Name $PowerShellModuleName
}

Function Load-SqlServerAssmblies
{
	# Declare parameters
    
	# Get the folder where the SqlServer module ended up in
	$sqlServerModulePath = [System.IO.Path]::GetDirectoryName((Get-Module SqlServer).Path)
    
    # Loop through the assemblies
    foreach($assemblyFile in (Get-ChildItem -Path $sqlServerModulePath -Exclude msv*.dll | Where-Object {$_.Extension -eq ".dll"}))
    {
        # Load the assembly
        [Reflection.Assembly]::LoadFile($assemblyFile.FullName) | Out-Null
    }    
}

#region Get-Catalog
Function Get-Catalog
{
     # define parameters
    Param ($CatalogName)
    # NOTE: using $integrationServices variable defined in main
    
    # define working varaibles
    $Catalog = $null
    # check to see if there are any catalogs
    if($integrationServices.Catalogs.Count -gt 0 -and $integrationServices.Catalogs[$CatalogName])
    {
    	# get reference to catalog
    	$Catalog = $integrationServices.Catalogs[$CatalogName]
    }
    else
    {
    	if((Get-CLREnabled) -eq 0)
    	{
    		if(-not $EnableCLR)
    		{
    			# throw error
    			throw "SQL CLR is not enabled."
    		}
    		else
    		{
    			# display sql clr isn't enabled
    			Write-Warning "SQL CLR is not enabled on $($sqlConnection.DataSource).  This feature must be enabled for SSIS catalogs."
    
    			# enablign SQLCLR
    			Write-Host "Enabling SQL CLR ..."
    			Enable-SQLCLR
    			Write-Host "SQL CLR enabled"
    		}
    	}
    
    	# Provision a new SSIS Catalog
    	Write-Host "Creating SSIS Catalog ..."
    
    	$Catalog = New-Object "$ISNamespace.Catalog" ($integrationServices, $CatalogName, $CatalogPwd)
    	$Catalog.Create()
    
    
    }
    
    # return the catalog
    return $Catalog
}
#endregion

#region Get-CLREnabled
Function Get-CLREnabled
{
    # define parameters
    # Not using any parameters, but am using $sqlConnection defined in main
    
    # define working variables
    $Query = "SELECT * FROM sys.configurations WHERE name = 'clr enabled'"
    
    # execute script
    $CLREnabled = Invoke-Sqlcmd -ServerInstance $sqlConnection.DataSource -Database "master" -Query $Query | Select value
    
    # return value
    return $CLREnabled.Value
}
#endregion

#region Enable-SQLCLR
Function Enable-SQLCLR
{
    $QueryArray = "sp_configure 'show advanced options', 1", "RECONFIGURE", "sp_configure 'clr enabled', 1", "RECONFIGURE "
    # execute script
    
    foreach($Query in $QueryArray)
    {
    	Invoke-Sqlcmd -ServerInstance $sqlConnection.DataSource -Database "master" -Query $Query
    }
    
    # check that it's enabled
    if((Get-CLREnabled) -ne 1)
    {
    	# throw error
    	throw "Failed to enable SQL CLR"
    }
}
#endregion

#region Get-Folder
Function Get-Folder
{
 # parameters
    Param($FolderName, $Catalog)
    
    $Folder = $null
    # try to get reference to folder
    
    if(!($Catalog.Folders -eq $null))
    {
    	$Folder = $Catalog.Folders[$FolderName]
    }
    
    # check to see if $Folder has a value
    if($Folder -eq $null)
    {
    	# display
    	Write-Host "Folder $FolderName doesn't exist, creating folder..."
    
    	# create the folder
    	$Folder = New-Object "$ISNamespace.CatalogFolder" ($Catalog, $FolderName, $FolderName) 
    	$Folder.Create() 
    }
    
    # return the folde reference
    return $Folder
}
#endregion

#region Get-Environment
Function Get-Environment
{
     # define parameters
    Param($Folder, $EnvironmentName)
    
    $Environment = $null
    # get reference to Environment
    if(!($Folder.Environments -eq $null) -and $Folder.Environments.Count -gt 0)
    {
    	$Environment = $Folder.Environments[$EnvironmentName]
    }
    
    # check to see if it's a null reference
    if($Environment -eq $null)
    {
    	# display
    	Write-Host "Environment $EnvironmentName doesn't exist, creating environment..."
    
    	# create environment
    	$Environment = New-Object "$ISNamespace.EnvironmentInfo" ($Folder, $EnvironmentName, $EnvironmentName)
    	$Environment.Create() 
    }
    
    # return the environment
    return $Environment
}
#endregion

#region Set-EnvironmentReference
Function Set-EnvironmentReference
{
     # define parameters
    Param($Project, $Environment, $Folder)
    
    # get reference
    $Reference = $null
    
    if(!($Project.References -eq $null))
    {
    	$Reference = $Project.References[$Environment.Name, $Folder.Name]
    
    }
    
    # check to see if it's a null reference
    if($Reference -eq $null)
    {
    	# display
    	Write-Host "Project does not reference environment $($Environment.Name), creating reference..."
    
    	# create reference
    	$Project.References.Add($Environment.Name, $Folder.Name)
    	$Project.Alter() 
    }
}
#endregion

#region Set-ProjectParametersToEnvironmentVariablesReference
Function Set-ProjectParametersToEnvironmentVariablesReference
{
     # define parameters
    Param($Project, $Environment)
    
    $UpsertedVariables = @()

    if($Project.Parameters -eq $null)
    {
        Write-Host "No project parameters exist"
        return
    }

    # loop through project parameters
    foreach($Parameter in $Project.Parameters)
    {
        # skip if the parameter is included in custom filters
        if ($UseCustomFilter) 
        {
            if ($Parameter.Name -match $CustomFilter)
            {
                Write-Host "- $($Parameter.Name) skipped due to CustomFilters."            
                continue
            }
        }

        # Add variable to list of variable
        $UpsertedVariables += $Parameter.Name

        $Variable = $null
        if(!($Environment.Variables -eq $null))
        {
    	    # get reference to variable
    	    $Variable = $Environment.Variables[$Parameter.Name]
        }
    
    	# check to see if variable exists
    	if($Variable -eq $null)
    	{
    		# add the environment variable
    		Add-EnvironmentVariable -Environment $Environment -Parameter $Parameter -ParameterName $Parameter.Name
    
    		# get reference to the newly created variable
    		$Variable = $Environment.Variables[$Parameter.Name]
    	}
    
    	# set the environment variable value
    	Set-EnvironmentVariableValue -Variable $Variable -Parameter $Parameter -ParameterName $Parameter.Name
    }
    
    # alter the environment
    $Environment.Alter()
    $Project.Alter()

    return $UpsertedVariables
}
#endregion

Function Set-PackageVariablesToEnvironmentVariablesReference
{
    # define parameters
    Param($Project, $Environment)

    $Variables = @()
    $UpsertedVariables = @()

    # loop through packages in project in order to store a temp collection of variables
    foreach($Package in $Project.Packages)
    {
    	# loop through parameters of package
    	foreach($Parameter in $Package.Parameters)
    	{
    		# add to the temporary variable collection
    		$Variables += $Parameter.Name
    	}
    }

    # loop through packages in project
    foreach($Package in $Project.Packages)
    {
    	# loop through parameters of package
    	foreach($Parameter in $Package.Parameters)
    	{
            if ($UseFullyQualifiedVariableNames)
            {
                # Set fully qualified variable name
                $ParameterName = $Parameter.ObjectName.Replace(".dtsx", "")+"."+$Parameter.Name
            }
            else
            {
                # check if exists a variable with the same name
                $VariableNameOccurrences = $($Variables | Where-Object { $_ -eq $Parameter.Name }).count
                $ParameterName = $Parameter.Name
                
                if ($VariableNameOccurrences -gt 1)
                {
                    $ParameterName = $Parameter.ObjectName.Replace(".dtsx", "")+"."+$Parameter.Name
                }
            }
            
            if ($UseCustomFilter)
            {
                if ($ParameterName -match $CustomFilter)
                {
                    Write-Host "- $($Parameter.Name) skipped due to CustomFilters."            
                    continue
                }
            }

            # get reference to variable
    		$Variable = $Environment.Variables[$ParameterName]

            # Add variable to list of variable
            $UpsertedVariables += $ParameterName

            # check to see if the parameter exists
    		if(!$Variable)
    		{
    			# add the environment variable
    			Add-EnvironmentVariable -Environment $Environment -Parameter $Parameter -ParameterName $ParameterName
    
    			# get reference to the newly created variable
    			$Variable = $Environment.Variables[$ParameterName]
    		}
    
    		# set the environment variable value
    		Set-EnvironmentVariableValue -Variable $Variable -Parameter $Parameter -ParameterName $ParameterName
    	}
    
    	# alter the package
    	$Package.Alter()
    }
    
    # alter the environment
    $Environment.Alter()

    return $UpsertedVariables
}

Function Sync-EnvironmentVariables
{
    # define parameters
    Param($Environment, $VariablesToPreserveInEnvironment)

    foreach($VariableToEvaluate in $Environment.Variables)
    {
        if ($VariablesToPreserveInEnvironment -notcontains $VariableToEvaluate.Name)
        {
            Write-Host "- Removing environment variable: $($VariableToEvaluate.Name)"
            $VariableToRemove = $Environment.Variables[$VariableToEvaluate.Name]
            $Environment.Variables.Remove($VariableToRemove) | Out-Null
        }
    }

    # alter the environment
    $Environment.Alter()
}

#region Add-EnvironmentVariable
Function Add-EnvironmentVariable
{
    # define parameters
    Param($Environment, $Parameter, $ParameterName)
    
    # display 
    Write-Host "- Adding environment variable $($ParameterName)"
    
    # check to see if design default value is emtpy or null
    if([string]::IsNullOrEmpty($Parameter.DesignDefaultValue))
    {
    	# give it something
    	$DefaultValue = "" # sensitive variables will not return anything so when trying to use the property of $Parameter.DesignDefaultValue, the Alter method will fail.
    }
    else
    {
    	# take the design
    	$DefaultValue = $Parameter.DesignDefaultValue
    }
    
    # add variable with an initial value
    $Environment.Variables.Add($ParameterName, $Parameter.DataType, $DefaultValue, $Parameter.Sensitive, $Parameter.Description)
}
#endregion

#region Set-EnvironmentVariableValue
Function Set-EnvironmentVariableValue
{
     # define parameters
    Param($Variable, $Parameter, $ParameterName)

    # check to make sure variable value is available
    if($OctopusParameters -and $OctopusParameters.ContainsKey($ParameterName))
    {
        # display 
        Write-Host "- Updating environment variable $($ParameterName)"

    	# set the variable value
    	$Variable.Value = $OctopusParameters["$($ParameterName)"]
    }
    else
    {
    	# warning
    	Write-Host "**- OctopusParameters collection is empty or $($ParameterName) not in the collection -**"
    }
    
    # Set reference
    $Parameter.Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "$($ParameterName)")
}
#endregion

# Define PowerShell Modules path
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules;$env:PSModulePath"

# Check to see if SqlServer module is installed
if ((Get-SqlModuleInstalled -PowerShellModuleName "SqlServer") -ne $true)
{
	# Display message
    Write-Output "PowerShell module SqlServer not present, downloading temporary copy ..."

	#Enable TLS 1.2 as default protocol
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

    # Download and install temporary copy
    Install-SqlServerPowerShellModule -PowerShellModuleName "SqlServer" -LocalModulesPath $LocalModules
    
	#region Dependent assemblies
	Load-SqlServerAssmblies    
}
else
{
	# Load the IntegrationServices Assembly
	[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices") | Out-Null # Out-Null supresses a message that would normally be displayed saying it loaded out of GAC
}

#endregion

# Store the IntegrationServices Assembly namespace to avoid typing it every time
$ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"

#endregion

#region Main
try
{   
    # ensure all boolean variables are true booleans
    $EnableCLR = [System.Convert]::ToBoolean("$EnableCLR")
    $UseEnvironment = [System.Convert]::ToBoolean("$UseEnvironment")
    $ReferenceProjectParametersToEnvironmentVairables = [System.Convert]::ToBoolean("$ReferenceProjectParametersToEnvironmentVairables")
    
    $ReferencePackageParametersToEnvironmentVairables = [System.Convert]::ToBoolean("$ReferencePackageParametersToEnvironmentVairables")
    $UseFullyQualifiedVariableNames = [System.Convert]::ToBoolean("$UseFullyQualifiedVariableNames")
    $SyncEnvironment = [System.Convert]::ToBoolean("$SyncEnvironment")
    # custom names for filtering out the excluded variables by design
    $UseCustomFilter = [System.Convert]::ToBoolean("$UseCustomFilter")
    $CustomFilter = [System.Convert]::ToString("$CustomFilter")
    # list of variables names to keep in target environment
    $VariablesToPreserveInEnvironment = @()
        
	# Get the extracted path
	$DeployedPath = $OctopusParameters["Octopus.Action.Package[$ssisPackageId].ExtractedPath"]
    
	# Get all .ispac files from the deployed path
	$IsPacFiles = Get-ChildItem -Recurse -Path $DeployedPath | Where {$_.Extension.ToLower() -eq ".ispac"}

	# display number of files
	Write-Host "$($IsPacFiles.Count) .ispac file(s) found."

	Write-Host "Connecting to server ..."

	# Create a connection to the server
    $sqlConnectionString = "Data Source=$ServerName;Initial Catalog=SSISDB;"
    
    if (![string]::IsNullOrEmpty($sqlAccountUsername) -and ![string]::IsNullOrEmpty($sqlAccountPassword))
    {
    	# Add username and password to connection string
        $sqlConnectionString += "User ID=$sqlAccountUsername; Password=$sqlAccountPassword;"
    }
    else
    {
    	# Use integrated
        $sqlConnectionString += "Integrated Security=SSPI;"
    }
    
    
    # Create new connection object with connection string
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString

	# create integration services object
	$integrationServices = New-Object "$ISNamespace.IntegrationServices" $sqlConnection

	# get reference to the catalog
	Write-Host "Getting reference to catalog $CataLogName"
	$Catalog = Get-Catalog -CatalogName $CataLogName

	# get folder reference
	$Folder = Get-Folder -FolderName $FolderName -Catalog $Catalog

	# loop through ispac files
	foreach($IsPacFile in $IsPacFiles)
	{
		# read project file
		$ProjectFile = [System.IO.File]::ReadAllBytes($IsPacFile.FullName)

		# deploy project
		Write-Host "Deploying project $($IsPacFile.Name)..."
		$Folder.DeployProject($ProjectName, $ProjectFile) | Out-Null

		# get reference to deployed project
		$Project = $Folder.Projects[$ProjectName]

		# check to see if they want to use environments
		if($UseEnvironment)
		{
			# get environment reference
			$Environment = Get-Environment -Folder $Folder -EnvironmentName $EnvironmentName

			# set environment reference
			Set-EnvironmentReference -Project $Project -Environment $Environment -Folder $Folder

			# check to see if the user wants to convert project parameters to environment variables
			if($ReferenceProjectParametersToEnvironmentVairables)
			{
				# set environment variables
				Write-Host "Referencing Project Parameters to Environment Variables..."
				$VariablesToPreserveInEnvironment += Set-ProjectParametersToEnvironmentVariablesReference -Project $Project -Environment $Environment
			}

			# check to see if the user wants to convert the package parameters to environment variables
			if($ReferencePackageParametersToEnvironmentVairables)
			{
				# set package variables
				Write-Host "Referencing Package Parameters to Environment Variables..."
				$VariablesToPreserveInEnvironment += Set-PackageVariablesToEnvironmentVariablesReference -Project $Project -Environment $Environment
			}
            
            # Removes all unused variables from the environment
            if ($SyncEnvironment)
            {
                Write-Host "Sync package environment variables..."
                Sync-EnvironmentVariables -Environment $Environment -VariablesToPreserveInEnvironment $VariablesToPreserveInEnvironment
            }
		}
	}
}

finally
{
	# check to make sure sqlconnection isn't null
	if($sqlConnection)
	{
		# check state of sqlconnection
		if($sqlConnection.State -eq [System.Data.ConnectionState]::Open)
		{
			# close the connection
			$sqlConnection.Close()
		}

		# cleanup
		$sqlConnection.Dispose()
	}
}
#endregion
