#Improve performance by turning off progress bar
#More details here: https://redgate.uservoice.com/forums/267000-sql-change-automation/suggestions/44882212-improve-performance-invoke-databasebuild-by-re
$ProgressPreference = "SilentlyContinue"

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
Write-Host "LocalModules: $LocalModules"
$env:PSModulePath = "$LocalModules;$env:PSModulePath"
Write-Host $env:PSModulePath

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

$SpecificModuleVersion = Optional -Parameter $SpecificModuleVersion
InstallCorrectSqlChangeAutomation -requiredVersion $SpecificModuleVersion

# Check if SQL Change Automation is installed.	
$powershellModule = Get-Module -Name SqlChangeAutomation	
if ($powershellModule -eq $null) { 	
    throw "Cannot find SQL Change Automation on your Octopus Tentacle. If SQL Change Automation is installed, try restarting the Tentacle service for it to be detected."	
}

$currentVersion = $powershellModule.Version	
$minimumRequiredVersion = [version] '3.0.3'	
if ($currentVersion -lt $minimumRequiredVersion) { 	
    throw "This step requires SQL Change Automation version $minimumRequiredVersion or later. The current version is $currentVersion. The latest version can be found at http://www.red-gate.com/sca/productpage"	
}

$minimumRequiredVersionDataCompareOptions = [version] '3.3.0'

# Check the parameters.
$DLMAutomationCustomConnectionString = Optional -Parameter $DLMAutomationCustomConnectionString

Required -Parameter $DLMAutomationDeploymentResourcesPath -Name 'Export Path'
Required -Parameter $DLMAutomationDeleteExistingFiles -Name 'Delete files in export folder'

if ([string]::IsNullOrWhiteSpace($DLMAutomationCustomConnectionString) -eq $true)
{
    Required -Parameter $DLMAutomationDatabaseServer -Name 'Target SQL Server instance'
    Required -Parameter $DLMAutomationDatabaseName -Name 'Target database name'
}

$DLMAutomationDatabaseUsername = Optional -Parameter $DLMAutomationDatabaseUsername
$DLMAutomationDatabasePassword = Optional -Parameter $DLMAutomationDatabasePassword
$DLMAutomationFilterPath = Optional -Parameter $DLMAutomationFilterPath
$DLMAutomationCompareOptions = Optional -Parameter $DLMAutomationCompareOptions
$DLMAutomationDataCompareOptions = Optional -Parameter $DLMAutomationDataCompareOptions
$DLMAutomationTransactionIsolationLevel = Optional -Parameter $DLMAutomationTransactionIsolationLevel -Default 'Serializable'
$DLMAutomationIgnoreStaticData = Optional -Parameter $DLMAutomationIgnoreStaticData -Default 'False'
$DLMAutomationIncludeIdenticalsInReport = Optional -Parameter $DLMAutomationIncludeIdenticalsInReport -Default 'False'
$DLMAutomationTrustServerCertificate = [Convert]::ToBoolean($OctopusParameters["DLMAutomationTrustServerCertificate"])

# Constructing the unique export path.
$projectId = $OctopusParameters["Octopus.Project.Id"]
$releaseNumber = $OctopusParameters["Octopus.Release.Number"]
$nugetPackageId = $OctopusParameters["Octopus.Action.Package[DLMAutomation.Package.Name].PackageId"]
$exportPath =  Join-Path (Join-Path (Join-Path $DLMAutomationDeploymentResourcesPath $projectId) $releaseNumber) $nugetPackageId

# Make sure the directory we're about to create doesn't already exist, and delete any files if requested.
if ((Test-Path $exportPath) -AND ((Get-ChildItem $exportPath | Measure-Object).Count -ne 0)) {
    if ($DLMAutomationDeleteExistingFiles -eq 'True') {
        Write-Host "Deleting all files in $exportPath"
        rmdir $exportPath -Recurse -Force
    } else {
        throw "The export path is not empty: $exportPath.  Select the 'Delete files in export folder' option to overwrite the existing folder contents."
    }
}


# Create and test connection to the database.
if ([string]::IsNullOrWhiteSpace($DLMAutomationCustomConnectionString) -eq $true)
{
    $databaseConnection = New-DatabaseConnection -ServerInstance $DLMAutomationDatabaseServer `
                                                    -Database $DLMAutomationDatabaseName `
                                                    -Username $DLMAutomationDatabaseUsername `
                                                    -Password $DLMAutomationDatabasePassword `
                                                    -TrustServerCertificate $DLMAutomationTrustServerCertificate | Test-DatabaseConnection
} else {
    $databaseConnection = New-Object -TypeName RedGate.Versioning.Automation.Compare.SchemaSources.DatabaseConnection `
                                        -ArgumentList $DLMAutomationCustomConnectionString | Test-DatabaseConnection
}

$packagePath = $OctopusParameters["Octopus.Action.Package[DLMAutomation.Package.Name].ExtractedPath"]

$importedBuildArtifact = Import-DatabaseBuildArtifact -Path $packagePath

# Only allow sqlcmd variables that don't have special characters like spaces, colon or dashes
$regex = '^[a-zA-Z_][a-zA-Z0-9_]+$'
$sqlCmdVariables = @{}
$OctopusParameters.Keys | Where { $_ -match $regex } | ForEach {
	$sqlCmdVariables[$_] = $OctopusParameters[$_]
}

# Create the deployment resources from the database to the NuGet package
$releaseParams = @{
    Target = $databaseConnection
    Source = $importedBuildArtifact
    TransactionIsolationLevel = $DLMAutomationTransactionIsolationLevel
    IgnoreStaticData = [bool]::Parse($DLMAutomationIgnoreStaticData)
    FilterPath = $DLMAutomationFilterPath
    SQLCompareOptions = $DLMAutomationCompareOptions
    IncludeIdenticalsInReport = [bool]::Parse($DLMAutomationIncludeIdenticalsInReport)
    SqlCmdVariables = $sqlCmdVariables
}

if($currentVersion -ge $minimumRequiredVersionDataCompareOptions) {
    $releaseParams.SQLDataCompareOptions = $DLMAutomationDataCompareOptions
} elseif(-not [string]::IsNullOrWhiteSpace($DLMAutomationDataCompareOptions)) {
    Write-Warning "SQL Data Compare options requires SQL Change Automation version $minimumRequiredVersionDataCompareOptions or later. The current version is $currentVersion."
}

$release = New-DatabaseReleaseArtifact @releaseParams

# Export the deployment resources to disk
$release | Export-DatabaseReleaseArtifact -Path $exportPath

# Import the changes summary, deployment warnings, and update script as Octopus artifacts, so you can review them.
function UploadIfExists() {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactPath,
        [Parameter(Mandatory = $true)]
        [string]$Name
    ) 
    if (Test-Path $ArtifactPath) {
        New-OctopusArtifact $ArtifactPath -Name $Name
    }
}

UploadIfExists -ArtifactPath "$exportPath\Reports\Changes.html" -Name "Changes-$DLMAutomationDatabaseName.html"
UploadIfExists -ArtifactPath "$exportPath\Reports\Drift.html" -Name "Drift-$DLMAutomationDatabaseName.html"
UploadIfExists -ArtifactPath "$exportPath\Reports\Warnings.xml" -Name "Warnings-$DLMAutomationDatabaseName.xml"
UploadIfExists -ArtifactPath "$exportPath\Update.sql" -Name "Update-$DLMAutomationDatabaseName.sql"
UploadIfExists -ArtifactPath "$exportPath\TargetedDeploymentScript.sql" -Name "TargetedDeploymentScript-$DLMAutomationDatabaseName.sql"
UploadIfExists -ArtifactPath "$exportPath\DriftRevertScript.sql" -Name "DriftRevertScript-$DLMAutomationDatabaseName.sql"

# Sets a variable if there are changes to deploy. Useful if you want to have steps run only when this is set
if ($release.UpdateSQL -notlike '*This script is empty because the Target and Source schemas are equivalent*')
{
  Set-OctopusVariable -name "ChangesToDeploy" -value "True"
}