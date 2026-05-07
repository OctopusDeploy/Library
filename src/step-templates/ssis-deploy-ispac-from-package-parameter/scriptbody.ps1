function Add-TemporaryPinnedSqlServerModule
{
    # Define parameters
    param(
        $LocalModulesPath
    )

    $PowerShellModuleName = "SqlServer"
    $RequiredVersion = [version]'21.1.18256'

    # Check to see if the package provider has been installed
    if ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
    {
        # Display that we need the nuget package provider
        Write-Host "Nuget package provider not found, installing ..."

        # Install Nuget package provider
        Install-PackageProvider -Name Nuget -Force
    }

    # Save the module in the temporary location
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force -RequiredVersion $RequiredVersion -Repository "PSGallery"

    # Display
    Write-Output "Saved module $PowerShellModuleName v$RequiredVersion to $LocalModulesPath"

    # Import the module
    Import-Module -Name $PowerShellModuleName
}

Function Remove-TemporaryPinnedSqlServerModule
{
    param(
        [Parameter(Mandatory = $true)][string]$LocalModulesPath,
        [Parameter(Mandatory = $true)][version]$PinnedVersion
    )

    try { Remove-Module SqlServer -Force -ErrorAction SilentlyContinue } catch {}

    $moduleRoot = Join-Path $LocalModulesPath 'SqlServer'
    $pinnedPath = Join-Path $moduleRoot $PinnedVersion.ToString()

    if (Test-Path $pinnedPath)
    {
        Write-Host "Removing temporary pinned SqlServer module folder: $pinnedPath"
        Remove-Item -Path $pinnedPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Optional: remove parent if empty
    if (Test-Path $moduleRoot)
    {
        $remaining = Get-ChildItem -Path $moduleRoot -Force -ErrorAction SilentlyContinue
        if (-not $remaining)
        {
            Remove-Item -Path $moduleRoot -Force -ErrorAction SilentlyContinue
        }
    }
}

Function Test-IntegrationServicesTypeAvailable
{
    # True if the IntegrationServices type resolves in this PowerShell session, else false
    $typeName = 'Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices'
    $aqn = "$typeName, Microsoft.SqlServer.Management.IntegrationServices"

    try
    {
        if ([Type]::GetType($aqn, $false)) { return $true }
    }
    catch {}

    # Try to load assembly (strong name), may fail on some boxes
    try { [void][Reflection.Assembly]::Load('Microsoft.SqlServer.Management.IntegrationServices') } catch {}

    try
    {
        if ([Type]::GetType($aqn, $false)) { return $true }
    }
    catch {}

    # Fall back to explicit GAC path load (LoadFrom) if present
    $gacRoot = Join-Path $env:windir 'Microsoft.NET\assembly\GAC_MSIL\Microsoft.SqlServer.Management.IntegrationServices'
    if (Test-Path $gacRoot)
    {
        $gacDll = Get-ChildItem -Path $gacRoot -Recurse -Filter 'Microsoft.SqlServer.Management.IntegrationServices.dll' -File -ErrorAction SilentlyContinue |
                  Sort-Object FullName -Descending |
                  Select-Object -First 1

        if ($null -eq $gacDll)
        {
            try
            {
                $asm = [Reflection.Assembly]::LoadFrom($gacDll.FullName)
                if ($asm.GetType('Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices', $false)) { return $true }
            }
            catch {}
        }
    }

    try
    {
        if ([Type]::GetType($aqn, $false)) { return $true }
    }
    catch {}

    return $false
}

Function Load-SqlServerAssemblies
{
    # Get the folder where the SqlServer module ended up in
    $sqlServerModulePath = [System.IO.Path]::GetDirectoryName((Get-Module SqlServer).Path)

    # Loop through the assemblies
    foreach($assemblyFile in (Get-ChildItem -Path $sqlServerModulePath -Exclude msv*.dll | Where-Object {$_.Extension -eq ".dll"}))
    {
        try
        {
            # Only load managed .NET assemblies (native DLLs will throw)
            [void][System.Reflection.AssemblyName]::GetAssemblyName($assemblyFile.FullName)

            # Load the managed assembly
            [Reflection.Assembly]::LoadFrom($assemblyFile.FullName) | Out-Null
        }
        catch [System.BadImageFormatException]
        {
            # Native DLL (or wrong format), skip
        }
    }
}

Function Initialize-SsisDeploymentRuntime
{
    param(
        [Parameter(Mandatory = $true)][string]$LocalModulesPath,
        [Parameter(Mandatory = $true)][version]$PinnedSqlServerVersion
    )

    # Define PowerShell Modules path
    $env:PSModulePath = "$LocalModulesPath;$env:PSModulePath"

    $runtime = [pscustomobject]@{
        UsedPinnedSqlServerModule = $false
        SsisTypeAvailable         = $false
    }

    # First preference: use SSIS assemblies already available on the machine/session
    $runtime.SsisTypeAvailable = Test-IntegrationServicesTypeAvailable

    if ($runtime.SsisTypeAvailable)
    {
        Write-Host "SSIS IntegrationServices type is already available."

        # Only need a SqlServer module for cmdlets such as Invoke-Sqlcmd
        if ($null -ne (Get-Module -ListAvailable -Name "SqlServer"))
        {
            Import-Module -Name SqlServer -ErrorAction Stop
        }
        else
        {
            Write-Output "PowerShell module SqlServer not present, downloading temporary pinned copy for cmdlets ..."
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

            Add-TemporaryPinnedSqlServerModule -LocalModulesPath $LocalModulesPath

            $manifestPath = Join-Path (Join-Path (Join-Path $LocalModulesPath 'SqlServer') $PinnedSqlServerVersion.ToString()) 'SqlServer.psd1'
            Write-Host "Importing pinned SqlServer module from: $manifestPath"
            Import-Module -Name $manifestPath -Force -DisableNameChecking -ErrorAction Stop

            $runtime.UsedPinnedSqlServerModule = $true
        }

        # SSIS type already resolved, no need to bulk-load module assemblies
        return $runtime
    }

    # Second preference: fall back to pinned SqlServer module that still contains SSIS assemblies
    Write-Output "SSIS IntegrationServices type not available via installed components. Downloading pinned SqlServer module $PinnedSqlServerVersion temporarily ..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

    $manifestPath = Join-Path (Join-Path (Join-Path $LocalModulesPath 'SqlServer') $PinnedSqlServerVersion.ToString()) 'SqlServer.psd1'
    if (-not (Test-Path $manifestPath))
    {
        Add-TemporaryPinnedSqlServerModule -LocalModulesPath $LocalModulesPath
    }

    Write-Host "Importing pinned SqlServer module from: $manifestPath"
    Import-Module -Name $manifestPath -Force -DisableNameChecking -ErrorAction Stop
    Load-SqlServerAssemblies

    $runtime.UsedPinnedSqlServerModule = $true
    $runtime.SsisTypeAvailable = Test-IntegrationServicesTypeAvailable

    return $runtime
}

Function Get-Catalog
{
    # define parameters
    Param ($CatalogName)
    # NOTE: using $integrationServices variable defined in main

    # define working variables
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

                # enabling SQLCLR
                Write-Host "Enabling SQL CLR ..."
                Enable-SQLCLR
                Write-Host "SQL CLR enabled"
            }
        }

        # Provision a new SSIS Catalog
        Write-Host "Creating SSIS Catalog ..."

        $Catalog = New-Object "$ISNamespace.Catalog" ($integrationServices, $CatalogName, $OctopusParameters['SSIS.Template.CatalogPwd'])
        $Catalog.Create()
    }

    # return the catalog
    return $Catalog
}

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

    # return the folder reference
    return $Folder
}

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

Function Add-EnvironmentVariable
{
    # define parameters
    Param($Environment, $Parameter, $ParameterName)

    # display
    Write-Host "- Adding environment variable $($ParameterName)"

    # check to see if design default value is empty or null
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

Function Set-EnvironmentVariableValue
{
     # define parameters
    Param($Variable, $Parameter, $ParameterName)

    # check to make sure variable value is available
    if (-not $OctopusParameters){
        Write-Host "[WARN] - OctopusParameters collection is empty"
    }
    else
    {
        if($OctopusParameters.ContainsKey($ParameterName))
        {
            # display
            Write-Host "[ OK ] - $($ParameterName) updated."

            # set the variable value
            $Variable.Value = $OctopusParameters["$($ParameterName)"]
        }
        else
        {
            # warning
            Write-Host "[WARN] - $($ParameterName) not in OctopusParameters collection."
        }
    }

    # Set reference
    $Parameter.Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "$($ParameterName)")
}

Function Invoke-SsisProjectDeployment
{
    $LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
    $pinnedSqlServerVersion = [version]'21.1.18256'
    $sqlConnection = $null
    $runtime = $null

    try
    {
        $runtime = Initialize-SsisDeploymentRuntime -LocalModulesPath $LocalModules -PinnedSqlServerVersion $pinnedSqlServerVersion

        # Store the IntegrationServices Assembly namespace to avoid typing it every time
        $ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"

        # ensure all boolean variables are true booleans
        $EnableCLR = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.EnableCLR'])")
        $UseEnvironment = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.UseEnvironment'])")
        $ReferenceProjectParametersToEnvironmentVairables = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.ReferenceProjectParametersToEnvironmentVairables'])")

        $ReferencePackageParametersToEnvironmentVairables = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.ReferencePackageParametersToEnvironmentVairables'])")
        $UseFullyQualifiedVariableNames = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.UseFullyQualifiedVariableNames'])")
        $SyncEnvironment = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.SyncEnvironment'])")
        # custom names for filtering out the excluded variables by design
        $UseCustomFilter = [System.Convert]::ToBoolean("$($OctopusParameters['SSIS.Template.UseCustomFilter'])")
        $CustomFilter = [System.Convert]::ToString("$($OctopusParameters['SSIS.Template.CustomFilter'])")
        # list of variables names to keep in target environment
        $VariablesToPreserveInEnvironment = @()
        $ssisPackageId = $OctopusParameters['SSIS.Template.ssisPackageId']

        # Get the extracted path
        $DeployedPath = $OctopusParameters["Octopus.Action.Package[$ssisPackageId].ExtractedPath"]

        # Get all .ispac files from the deployed path
        $IsPacFiles = Get-ChildItem -Recurse -Path $DeployedPath | Where {$_.Extension.ToLower() -eq ".ispac"}

        # display number of files
        Write-Host "$($IsPacFiles.Count) .ispac file(s) found."

        Write-Host "Connecting to server ..."

        # Create a connection to the server
        $sqlConnectionString = "Data Source=$($OctopusParameters['SSIS.Template.ServerName']);Initial Catalog=SSISDB;"

        if (![string]::IsNullOrEmpty($OctopusParameters['SSIS.Template.sqlAccountUsername']) -and ![string]::IsNullOrEmpty($OctopusParameters['SSIS.Template.sqlAccountPassword']))
        {
            # Add username and password to connection string
            $sqlConnectionString += "User ID=$($OctopusParameters['SSIS.Template.sqlAccountUsername']); Password=$($OctopusParameters['SSIS.Template.sqlAccountPassword']);"
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
        Write-Host "Getting reference to catalog $($OctopusParameters['SSIS.Template.CataLogName'])"
        $Catalog = Get-Catalog -CatalogName $OctopusParameters['SSIS.Template.CataLogName']

        # get folder reference
        $Folder = Get-Folder -FolderName $OctopusParameters['SSIS.Template.FolderName'] -Catalog $Catalog

        # loop through ispac files
        foreach($IsPacFile in $IsPacFiles)
        {
            # read project file
            $ProjectFile = [System.IO.File]::ReadAllBytes($IsPacFile.FullName)
            $ProjectName = $IsPacFile.Name.SubString(0, $IsPacFile.Name.LastIndexOf("."))

            # deploy project
            Write-Host "Deploying project $($IsPacFile.Name)..."
            $Folder.DeployProject($ProjectName, $ProjectFile) | Out-Null

            # get reference to deployed project
            $Project = $Folder.Projects[$ProjectName]

            # check to see if they want to use environments
            if($UseEnvironment)
            {
                # get environment reference
                $Environment = Get-Environment -Folder $Folder -EnvironmentName $OctopusParameters['SSIS.Template.EnvironmentName']

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

        # cleanup temporary pinned SqlServer module only when it was actually used
        if ($runtime -and $runtime.UsedPinnedSqlServerModule)
        {
            Remove-TemporaryPinnedSqlServerModule -LocalModulesPath $LocalModules -PinnedVersion $pinnedSqlServerVersion
        }
    }
}

Invoke-SsisProjectDeployment