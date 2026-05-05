function Get-NugetPackageProviderNotInstalled
{
	# See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

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


# Force use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$autoReboot = [System.Convert]::ToBoolean("$windowsUpdateAutoReboot")

# Check to see if the NuGet package provider is installed
if ((Get-NugetPackageProviderNotInstalled) -ne $false)
{
  # Display that we need the nuget package provider
  Write-Host "Nuget package provider not found, installing ..."

  # Install Nuget package provider
  Install-PackageProvider -Name Nuget -Force

  Write-Output "Nuget package provider succesfully installed ..."
}


Write-Output "Checking for PowerShell module PSWindowsUpdate ..."

if ((Get-ModuleInstalled -PowerShellModuleName "PSWindowsUpdate") -ne $true)
{
	Write-Output "PSWindowsUpdate not found, installing ..."
    
    # Install PSWindowsUpdate
    Install-Module PSWindowsUpdate -Force
    
    Write-Output "Installation of PSWindowsUpdate complete ..."
}

Write-Output "Checking for updates ..."

$windowsUpdates = Get-WindowsUpdate 

# Check to see if there's anything to install
if ($windowsUpdates.Count -gt 0)
{
	Write-Output "Installing updates ..."
    if ($autoReboot)
    {
		Install-WindowsUpdate -AcceptAll -AutoReboot
    }
    else
    {
    	Install-WindowsUpdate -AcceptAll
    }
}
else
{
	Write-Output "There are no updates available."
}