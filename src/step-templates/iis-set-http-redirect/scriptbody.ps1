# Set temporary location for PowerShell modules
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules;$env:PSModulePath"
$iisPath = "IIS:\Sites\$iisSiteName"

# Convert checkbox variables into true Boolean object types
$enableRedirect = [System.Convert]::ToBoolean($enableRedirect)
$exactDestination = [System.Convert]::ToBoolean($exactDestination)

function Get-ModuleInstalled
{
    # Define parameters
    param(
        $PowerShellModuleName
    )

    # Get list of installed modules
    $installedModules = Get-Module -ListAvailable

    # Check to see if the module is installed
    if ($null -ne ($installedModules | Where-Object {$_.Name -eq $PowerShellModuleName}))
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

function Install-TemporaryPowerShellModule
{
    # Define parameters
    param(
        $PowerShellModuleName,
        $LocalModulesPath
    )

    # Save the module in the temporary location
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force
}

# Check to see if WebAdministration module installed
if (!(Get-ModuleInstalled -PowerShellModuleName "WebAdministration"))
{
    # Temporarily install module
    Write-Output "Tempoarily installing PowerShell module WebAdministration."

    Install-TemporaryPowerShellModule -PowerShellModuleName "WebAdministration" -LocalModulesPath $LocalModules
}

# Import the WebAdministartion module
Import-Module -Name "WebAdministration"

# Verify the site exists
if ($null -eq (Get-WebSite -Name $iisSiteName))
{
    # Throw error
    throw "Site $iisSiteName not found!"
}

# Check to see if the an application was specified
if (!([string]::IsNullOrEmpty($iisApplicationName)))
{
    # Verify the appliation exists
    if ($null -eq (Get-WebApplication -Site $iisSiteName -Name $iisApplicationName))
    {
        # Throw error
        throw "Web application $iisApplicationName not found on site $iisSiteName!"
    }

    # Append application name to iis path
    $iisPath += "\$iisApplicationName"
}

# Set redirect on application
Set-WebConfiguration system.webserver/httpRedirect -PSPath $iisPath -Value @{enabled="$enableRedirect";destination="$redirectUrl";exactDestination="$exactDestination";httpResponseStatus="$httpResponseStatus"}
