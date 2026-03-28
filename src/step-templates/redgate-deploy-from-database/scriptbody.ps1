function GetModuleInstallationFolder
{
    if (ModuleInstallationFolderIsValid)
    {
        return [System.IO.Path]::GetFullPath($DLMAutomationModuleInstallationFolder)
    }

    return "$PSScriptRoot\Modules"
}

function ModuleInstallationFolderIsValid
{
    if ([string]::IsNullOrWhiteSpace($DLMAutomationModuleInstallationFolder))
    {
        return $false
    }

    return (Test-Path $DLMAutomationModuleInstallationFolder -IsValid) -eq $true;
}

$DlmAutomationModuleName = "DLMAutomation"
$SqlChangeAutomationModuleName = "SqlChangeAutomation"
$ModulesFolder = GetModuleInstallationFolder
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
        [Version]$requiredVersion,
        [Parameter(Mandatory = $false)]
        [bool]$useInstalledVersion
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

    if ($useInstalledVersion) {
        Write-Verbose "Option to use installed version is selected. Skipping update/install using PowerShellGet."
    }
    else {
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

    ConfigureProxyIfVariableSet
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

function ConfigureProxyIfVariableSet
{
    if ([string]::IsNullOrWhiteSpace($DLMAutomationProxyUrl) -eq $false)
    {
        Write-Debug "Setting DefaultWebProxy to $proxyUrl"

        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($DLMAutomationProxyUrl)
        [System.Net.WebRequest]::DefaultWebProxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        [System.Net.WebRequest]::DefaultWebProxy.BypassProxyOnLocal = $True
    }
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
$UseInstalledModuleVersion = Optional -Parameter $UseInstalledModuleVersion -Default 'False'
$UseInstalledVersionSwitch = [bool]::Parse($UseInstalledModuleVersion)
InstallCorrectSqlChangeAutomation -requiredVersion $SpecificModuleVersion -useInstalledVersion $UseInstalledVersionSwitch

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
$minimumRequiredVersionTrustServerCertificate = [version]'4.3.20267'

function AreConnectionOptionsHandled($encryptConnection, $trustServerCertificate)
{
    if ([string]::IsNullOrWhiteSpace($currentVersion) -or $currentVersion -ge $minimumRequiredVersionTrustServerCertificate)
    {
        return $true
    }
    elseif($encryptConnection -or $trustServerCertificate)
    {
        Write-Warning "Encrypt and TrustServerCertificate options require SQL Change Automation version $minimumRequiredVersionTrustServerCertificate or later. The current version is $currentVersion."
        return $false
    }
}

# Check the parameters.
Required -Parameter $DLMAutomationSourceDatabaseServer -Name 'Source SQL Server instance'
Required -Parameter $DLMAutomationSourceDatabaseName -Name 'Source database name'
$DLMAutomationSourceUsername = Optional -Parameter $DLMAutomationSourceUsername
$DLMAutomationSourcePassword = Optional -Parameter $DLMAutomationSourcePassword
$DLMAutomationSourceTrustServerCertificate = Optional -Parameter $DLMAutomationSourceTrustServerCertificate
$DLMAutomationSourceEncrypt = Optional -Parameter $DLMAutomationSourceEncrypt
Required -Parameter $DLMAutomationTargetDatabaseServer -Name 'Target SQL Server instance'
Required -Parameter $DLMAutomationTargetDatabaseName -Name 'Target database name'
$DLMAutomationTargetUsername = Optional -Parameter $DLMAutomationTargetUsername
$DLMAutomationTargetPassword = Optional -Parameter $DLMAutomationTargetPassword
$DLMAutomationTargetTrustServerCertificate = Optional -Parameter $DLMAutomationTargetTrustServerCertificate
$DLMAutomationTargetEncrypt = Optional -Parameter $DLMAutomationTargetEncrypt
$DLMAutomationFilterPath = Optional -Parameter $DLMAutomationFilterPath
$DLMAutomationCompareOptions = Optional -Parameter $DLMAutomationCompareOptions
$DLMAutomationDataCompareOptions = Optional -Parameter $DLMAutomationDataCompareOptions
$DLMAutomationTransactionIsolationLevel = Optional -Parameter $DLMAutomationTransactionIsolationLevel -Default 'Serializable'
$DLMAutomationSkipPostUpdateSchemaCheck = Optional -Parameter $DLMAutomationSkipPostUpdateSchemaCheck -Default "False"
$DLMAutomationQueryBatchTimeout = Optional -Parameter $DLMAutomationQueryBatchTimeout -Default '30'
$DLMAutomationModuleInstallationFolder = Optional -Parameter $DLMAutomationModuleInstallationFolder
$DLMAutomationProxyUrl = Optional -Parameter $DLMAutomationProxyUrl

$skipPostUpdateSchemaCheck = RequireBool -Parameter $DLMAutomationSkipPostUpdateSchemaCheck -Name 'Skip post update schema check'
$queryBatchTimeout = RequirePositiveNumber -Parameter $DLMAutomationQueryBatchTimeout -Name 'Query Batch Timeout'


$targetConnectionOptions = @{ }
$sourceConnectionOptions = @{ }

if(AreConnectionOptionsHandled([bool]::Parse($DLMAutomationTargetEncrypt) -or [bool]::Parse($DLMAutomationSourceEncrypt), `
                               [bool]::Parse($DLMAutomationTargetTrustServerCertificate) -or [bool]::Parse($DLMAutomationSourceTrustServerCertificate))) {
    $targetConnectionOptions += @{ 'Encrypt' = [bool]::Parse($DLMAutomationTargetEncrypt) }
    $targetConnectionOptions += @{ 'TrustServerCertificate' = [bool]::Parse($DLMAutomationTargetTrustServerCertificate) }
	$sourceConnectionOptions += @{ 'Encrypt' = [bool]::Parse($DLMAutomationSourceEncrypt) }
    $sourceConnectionOptions += @{ 'TrustServerCertificate' = [bool]::Parse($DLMAutomationSourceTrustServerCertificate) }
}

$targetDB = New-DatabaseConnection @targetConnectionOptions `
                                   -ServerInstance $DLMAutomationTargetDatabaseServer `
                                   -Database $DLMAutomationTargetDatabaseName `
                                   -Username $DLMAutomationTargetUsername `
                                   -Password $DLMAutomationTargetPassword | Test-DatabaseConnection

$sourceDB = New-DatabaseConnection @sourceConnectionOptions `
								   -ServerInstance $DLMAutomationSourceDatabaseServer `
                                   -Database $DLMAutomationSourceDatabaseName `
                                   -Username $DLMAutomationSourceUsername `
                                   -Password $DLMAutomationSourcePassword | Test-DatabaseConnection

# Create the deployment resources, only adding the arguments that are not null or empty.
$releaseParams = @{
    Target = $targetDB
    Source = $sourceDB
    TransactionIsolationLevel = $DLMAutomationTransactionIsolationLevel
    FilterPath = $DLMAutomationFilterPath
    SQLCompareOptions = $DLMAutomationCompareOptions
}

if($currentVersion -ge $minimumRequiredVersionDataCompareOptions) {
    $releaseParams.SQLDataCompareOptions = $DLMAutomationDataCompareOptions
} elseif(-not [string]::IsNullOrWhiteSpace($DLMAutomationDataCompareOptions)) {
    Write-Warning "SQL Data Compare options requires SQL Change Automation version $minimumRequiredVersionDataCompareOptions or later. The current version is $currentVersion."
}

$release = New-DatabaseReleaseArtifact @releaseParams

$releaseUrl = $OctopusParameters['#{if Octopus.Web.ServerUri}#{Octopus.Web.ServerUri}#{else}#{Octopus.Web.BaseUrl}#{/if}'] + $OctopusParameters['Octopus.Web.DeploymentLink'];
# Deploy the source schema to the target database.
$release | Use-DatabaseReleaseArtifact -DeployTo $targetDB -SkipPreUpdateSchemaCheck -QueryBatchTimeout $queryBatchTimeout -ReleaseUrl $releaseUrl -SkipPostUpdateSchemaCheck:$skipPostUpdateSchemaCheck
