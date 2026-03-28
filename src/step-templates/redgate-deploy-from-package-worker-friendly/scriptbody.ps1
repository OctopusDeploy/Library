$DlmAutomationModuleName = "DLMAutomation"
$SqlChangeAutomationModuleName = "SqlChangeAutomation"
$ModulesFolder = "$Home\Documents\WindowsPowerShell\Modules"


if ([string]::IsNullOrWhiteSpace($DLMModuleInstallLocation) -eq $false)
{
	if ((Test-Path $DLMModuleInstallLocation -IsValid) -eq $false)
    {
    	Write-Error "The path $DLMModuleInstallLocation is not valid, please use a relative or absolute path."
        exit 1
    }
    
    $ModulesFolder = [System.IO.Path]::GetFullPath($DLMModuleInstallLocation)            
}

Write-Host "Modules will be installed into $ModulesFolder"

$LocalModules = (New-Item "$ModulesFolder" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules;$env:PSModulePath"

function IsScaAvailable
{
    if ((Get-Module $SqlChangeAutomationModuleName) -ne $null) {
        return $true
    }

    return $false
}

function InstallCorrectSqlChangeAutomation
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [Version]$requiredVersion
    )

    $moduleName = $SqlChangeAutomationModuleName

    # this will be null if $requiredVersion is not specified - which is exactly what we want
    $maximumVersion = $requiredVersion

    if ($requiredVersion) {
        if ($requiredVersion.Revision -eq -1) {
            #If provided with a 3 part version number (the 4th part, revision, == -1), we should allow any value for the revision
            $maximumVersion = [Version]"$requiredVersion.$([System.Int32]::MaxValue)"
        }

        if ($requiredVersion.Major -lt 3) {
            # If the specified version is below V3 then the user is requesting a version of DLMA. We should look for that module name instead
            $moduleName = $DlmAutomationModuleName
        }
    }

    $installedModule = GetHighestInstalledModule $moduleName -minimumVersion $requiredVersion -maximumVersion $maximumVersion

    if (!$installedModule) {
        #Either SCA isn't installed at all or $requiredVersion is specified but that version of SCA isn't installed
        Write-Verbose "$moduleName $requiredVersion not available - attempting to download from gallery"
        InstallLocalModule -moduleName $moduleName -minimumVersion $requiredVersion -maximumVersion $maximumVersion
    }
    elseif (!$requiredVersion) {
        #We've got a version of SCA installed, but $requiredVersion isn't specified so we might be able to upgrade
        $newest = GetHighestInstallableModule $moduleName
        if ($newest -and ($installedModule.Version -lt $newest.Version)) {
            Write-Verbose "Updating $moduleName to version $($newest.Version)"
            InstallLocalModule -moduleName $moduleName -minimumVersion $newest.Version
        }
    }

    # Now we're done with install/upgrade, try to import the highest available module that matches our version requirements

    # We can't just use -minimumVersion and -maximumVersion arguments on Import-Module because PowerShell 3 doesn't have them,
    # so we have to find the precise matching installed version using our code, then import that specifically. Note that
    # $requiredVersion and $maximumVersion might be null when there's no specific version we need.
    $installedModule = GetHighestInstalledModule $moduleName -minimumVersion $requiredVersion -maximumVersion $maximumVersion

    if (!$installedModule -and !$requiredVersion) {
        #Did not find SCA, and we don't have a required version so we might be able to use an installed DLMA instead.
        Write-Verbose "$moduleName is not installed - trying to fall back to $DlmAutomationModuleName"
        $installedModule = GetHighestInstalledModule $DlmAutomationModuleName
    }

    if ($installedModule) {
        Write-Verbose "Importing installed $($installedModule.Name) version $($installedModule.Version)"
        Import-Module $installedModule -Force
    }
    else {
        throw "$moduleName $requiredVersion is not installed, and could not be downloaded from the PowerShell gallery"
    }
}

function InstallPowerShellGet {
    [CmdletBinding()]
    Param()

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $psget = GetHighestInstalledModule PowerShellGet
    if (!$psget)
    {
        Write-Warning @"
Cannot access the PowerShell Gallery because PowerShellGet is not installed.
To install PowerShellGet, either upgrade to PowerShell 5 or install the PackageManagement MSI.
See https://docs.microsoft.com/en-us/powershell/gallery/installing-psget for more details.
"@
        throw "PowerShellGet is not available"
    }

    if ($psget.Version -lt [Version]'1.6') {
        #Bootstrap the NuGet package provider, which updates NuGet without requiring admin rights
        Write-Debug "Installing NuGet package provider"
        Get-PackageProvider NuGet -ForceBootstrap | Out-Null

        #Use the currently-installed version of PowerShellGet
        Import-PackageProvider PowerShellGet

        #Download the version of PowerShellGet that we actually need
        Write-Debug "Installing PowershellGet"
        Save-Module -Name PowerShellGet -Path $LocalModules -MinimumVersion 1.6 -Force -ErrorAction SilentlyContinue
    }

    Write-Debug "Importing PowershellGet"
    Import-Module PowerShellGet -MinimumVersion 1.6 -Force
    #Make sure we're actually using the package provider from the imported version of PowerShellGet
    Import-PackageProvider ((Get-Module PowerShellGet).Path) | Out-Null
}

function InstallLocalModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$moduleName,
        [Parameter(Mandatory = $false)]
        [Version]$minimumVersion,
        [Parameter(Mandatory = $false)]
        [Version]$maximumVersion
    )
    try {
        InstallPowerShellGet

        Write-Debug "Install $moduleName $requiredVersion"
        Save-Module -Name $moduleName -Path $LocalModules -Force -AcceptLicense -MinimumVersion $minimumVersion -MaximumVersion $maximumVersion -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not install $moduleName $requiredVersion from any registered PSRepository"
    }
}

function GetHighestInstalledModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $moduleName,

        [Parameter(Mandatory = $false)]
        [Version]$minimumVersion,
        [Parameter(Mandatory = $false)]
        [Version]$maximumVersion
    )

    return Get-Module $moduleName -ListAvailable |
           Where {(!$minimumVersion -or ($_.Version -ge $minimumVersion)) -and (!$maximumVersion -or ($_.Version -le $maximumVersion))} |
           Sort -Property @{Expression = {[System.Version]($_.Version)}; Descending = $True} |
           Select -First 1
}

function GetHighestInstallableModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $moduleName
    )

    try {
        InstallPowerShellGet
        Find-Module SqlChangeAutomation -AllVersions |
            Sort -Property @{Expression = {[System.Version]($_.Version)}; Descending = $True} |
            Select -First 1
    }
    catch {
        Write-Warning "Could not find any suitable versions of $moduleName from any registered PSRepository"
    }
}

function GetInstalledSqlChangeAutomationVersion {
    $scaModule = (Get-Module $SqlChangeAutomationModuleName)

    if ($scaModule -ne $null) {
        return $scaModule.Version
    }

    $dlmaModule = (Get-Module $DlmAutomationModuleName)

    if ($dlmaModule -ne $null) {
        return $dlmaModule.Version
    }

    return $null
}

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Set process level FUR environment
$env:REDGATE_FUR_ENVIRONMENT = "Octopus Step Templates"

#Helper functions for paramter handling
function Required() {
    Param(
        [Parameter(Mandatory = $false)][string]$Parameter, 
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Parameter)) { throw "You must enter a value for '$Name'" }
}
function Optional() {
    #Default is untyped here - if we specify [string] powershell will convert nulls into empty string
    Param(
        [Parameter(Mandatory = $false)][string]$Parameter, 
        [Parameter(Mandatory = $false)]$Default
    )
    if ([string]::IsNullOrWhiteSpace($Parameter)) { 
        $Default
    } else { 
        $Parameter
    }
}
function RequireBool() {
    Param(
        [Parameter(Mandatory = $false)][string]$Parameter, 
        [Parameter(Mandatory = $true)][string]$Name
    )
    $Result = $False
    if (![bool]::TryParse($Parameter , [ref]$Result )) { throw "'$Name' must be a boolean value." }
    $Result
}
function RequirePositiveNumber() {
    Param(
        [Parameter(Mandatory = $false)][string]$Parameter, 
        [Parameter(Mandatory = $true)][string]$Name
    )
    $Result = 0
    if (![int32]::TryParse($Parameter , [ref]$Result )) { throw "'$Name' must be a numerical value." }
    if ($Result -lt 0) { throw "'$Name' must be >= 0." }
    $Result
}

function Get-SqlcmdInstalled
{
	# Define variables
    $searchPaths = @("c:\program files\microsoft sql server", "c:\program files (x86)\microsoft sql server")
    
    # Loop through search paths
    foreach ($searchPath in $searchPaths)
    {
    	# Ensure folder exists
        if (Test-Path -Path $searchPath)
        {
        	# Search the path
            return ($null -ne (Get-ChildItem -Path $searchPath -Recurse | Where-Object {$_.Name -eq "sqlcmd.exe"}))
        }
    }
    
    # Not found
    return $false
}

$SpecificModuleVersion = Optional -Parameter $SpecificModuleVersion
InstallCorrectSqlChangeAutomation -requiredVersion $SpecificModuleVersion

# Check if SQL Change Automation is installed.	
$powershellModule = Get-Module -Name SqlChangeAutomation	
if ($powershellModule -eq $null) { 	
    throw "Cannot find SQL Change Automation on your Octopus Tentacle. If SQL Change Automation is installed, try restarting the Tentacle service for it to be detected."	
}

# Check to for sqlcmd
$sqlCmdExists = Get-SqlCmdInstalled

if ($sqlCmdExists -eq $false)
{
	Write-Verbose "This template requires the sqlcmd utility, downloading ..."
	$tempPath = (New-Item "$PSScriptRoot\sqlcmd" -ItemType Directory -Force).FullName
    
	$sqlCmdUrl = ""
    $odbcUrl = ""
    $redistributableUrl = ""
    
    switch ($Env:PROCESSOR_ARCHITECTURE)
    {
    	"AMD64"
        {
        	$sqlCmdUrl = "https://go.microsoft.com/fwlink/?linkid=2142258"
            $odbcUrl = "https://go.microsoft.com/fwlink/?linkid=2168524"
            $redistributableUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            break
        }
        "x86"
        {
        	$sqlCmdUrl = "https://go.microsoft.com/fwlink/?linkid=2142257"
            $odbcUrl = "https://go.microsoft.com/fwlink/?linkid=2168713"
            $redistributableUrl = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
            break
        }
    }
    
    Invoke-WebRequest -Uri $sqlCmdUrl -OutFile "$tempPath\sqlcmd.msi" -UseBasicParsing
	Invoke-WebRequest -Uri $odbcUrl -OutFile "$tempPath\msodbc.msi" -UseBasicParsing
	Invoke-WebRequest -Uri $redistributableUrl -Outfile "$tempPath\vc_redist.exe" -UseBasicParsing

	Write-Verbose "Installing Visual Studio 2017 C++ redistrutable prequisite ..."
	Start-Process -FilePath "$tempPath\vc_redist.exe" -ArgumentList @("/install", "/passive", "/norestart") -NoNewWindow -Wait
    Write-Verbose "Installing SQL Server 2017 ODBC driver prequisite ..."
	Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "$tempPath\msodbc.msi", "IACCEPTMSODBCSQLLICENSETERMS=YES", "/qn") -NoNewWindow -Wait
    Write-Verbose "Installing SQLCMD utility ..."
	Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "$tempPath\sqlcmd.msi", "IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES", "/qn") -NoNewWindow -Wait

	Write-Verbose "Sqlcmd Installation complete!"
}

$currentVersion = $powershellModule.Version	
$minimumRequiredVersion = [version] '3.0.3'	
if ($currentVersion -lt $minimumRequiredVersion) { 	
    throw "This step requires SQL Change Automation version $minimumRequiredVersion or later. The current version is $currentVersion. The latest version can be found at http://www.red-gate.com/sca/productpage"	
}

$minimumRequiredVersionDataCompareOptions = [version] '3.3.0'

# Check the parameters.
$DLMAutomationCustomConnectionString = Optional -Parameter $DLMAutomationCustomConnectionString

if ([string]::IsNullOrWhiteSpace($DLMAutomationCustomConnectionString) -eq $true)
{
    Required -Parameter $DLMAutomationTargetDatabaseServer -Name 'Target SQL Server instance'
    Required -Parameter $DLMAutomationTargetDatabaseName -Name 'Target database name'
}

$DLMAutomationTargetUsername = Optional -Parameter $DLMAutomationTargetUsername
$DLMAutomationTargetPassword = Optional -Parameter $DLMAutomationTargetPassword
$DLMAutomationFilterPath = Optional -Parameter $DLMAutomationFilterPath
$DLMAutomationCompareOptions = Optional -Parameter $DLMAutomationCompareOptions
$DLMAutomationDataCompareOptions = Optional -Parameter $DLMAutomationDataCompareOptions
$DLMAutomationTransactionIsolationLevel = Optional -Parameter $DLMAutomationTransactionIsolationLevel -Default "Serializable"
$DLMAutomationIgnoreStaticData = Optional -Parameter $DLMAutomationIgnoreStaticData -Default 'False'
$DLMAutomationSkipPostUpdateSchemaCheck = Optional -Parameter $DLMAutomationSkipPostUpdateSchemaCheck -Default "False"
$DLMAutomationQueryBatchTimeout = Optional -Parameter $DLMAutomationQueryBatchTimeout -Default '30'
$DLMAutomationTrustServerCertificate = [Convert]::ToBoolean($OctopusParameters["DLMAutomationTrustServerCertificate"])

$skipPostUpdateSchemaCheck = RequireBool -Parameter $DLMAutomationSkipPostUpdateSchemaCheck -Name 'Skip post update schema check'
$queryBatchTimeout = RequirePositiveNumber -Parameter $DLMAutomationQueryBatchTimeout -Name 'Query Batch Timeout'

# Create and test connection to the database.
if ([string]::IsNullOrWhiteSpace($DLMAutomationCustomConnectionString) -eq $true)
{
    $databaseConnection = New-DatabaseConnection -ServerInstance $DLMAutomationTargetDatabaseServer `
                                                    -Database $DLMAutomationTargetDatabaseName `
                                                    -Username $DLMAutomationTargetUsername `
                                                    -Password $DLMAutomationTargetPassword `
                                                    -TrustServerCertificate $DLMAutomationTrustServerCertificate | Test-DatabaseConnection
} else {
    $databaseConnection = New-Object -TypeName RedGate.Versioning.Automation.Compare.SchemaSources.DatabaseConnection `
                                        -ArgumentList $DLMAutomationCustomConnectionString | Test-DatabaseConnection
}
$packageExtractPath = $OctopusParameters["Octopus.Action.Package[DLMAutomation.Package.Name].ExtractedPath"]
$importedBuildArtifact = Import-DatabaseBuildArtifact -Path $packageExtractPath

# Only allow sqlcmd variables that don't have special characters like spaces, colon or dashes
$regex = '^[a-zA-Z_][a-zA-Z0-9_]+$'
$sqlCmdVariables = @{}
$OctopusParameters.Keys | Where { $_ -match $regex } | ForEach {
	$sqlCmdVariables[$_] = $OctopusParameters[$_]
}

# Create database deployment resources from the NuGet package to the database
$releaseParams = @{
    Target = $databaseConnection
    Source = $importedBuildArtifact
    TransactionIsolationLevel = $DLMAutomationTransactionIsolationLevel
    IgnoreStaticData = [bool]::Parse($DLMAutomationIgnoreStaticData)
    FilterPath = $DLMAutomationFilterPath
    SQLCompareOptions = $DLMAutomationCompareOptions
    SqlCmdVariables = $sqlCmdVariables
}

if($currentVersion -ge $minimumRequiredVersionDataCompareOptions) {
    $releaseParams.SQLDataCompareOptions = $DLMAutomationDataCompareOptions
} elseif(-not [string]::IsNullOrWhiteSpace($DLMAutomationDataCompareOptions)) {
    Write-Warning "SQL Data Compare options requires SQL Change Automation version $minimumRequiredVersionDataCompareOptions or later. The current version is $currentVersion."
}

$release = New-DatabaseReleaseArtifact @releaseParams

# Deploy the source schema to the target database.
Write-Host "Timeout = $queryBatchTimeout"
$releaseUrl = $OctopusParameters['Octopus.Web.ServerUri'] + $OctopusParameters['Octopus.Web.DeploymentLink']; 
$release | Use-DatabaseReleaseArtifact -DeployTo $databaseConnection -SkipPreUpdateSchemaCheck -QueryBatchTimeout $queryBatchTimeout -ReleaseUrl $releaseUrl -SkipPostUpdateSchemaCheck:$skipPostUpdateSchemaCheck

