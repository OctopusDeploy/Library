[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$Server = $OctopusParameters["Venafi.TPP.RevokeOAuth.Server"]
$Token = $OctopusParameters["Venafi.TPP.RevokeOAuth.AccessToken"]

# Validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.RevokeOAuth.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Required parameter Venafi.TPP.RevokeOAuth.AccessToken not specified"
}

$SecureToken = ConvertTo-SecureString $Token -AsPlainText -Force
[PSCredential]$AccessToken = New-Object System.Management.Automation.PsCredential("token", $SecureToken)

# Clean-up
$Server = $Server.TrimEnd('/')

# Required Modules
function Get-NugetPackageProviderNotInstalled {
    # See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

# Check to see if the package provider has been installed
if ((Get-NugetPackageProviderNotInstalled) -ne $false) {
    Write-Host "Nuget package provider not found, installing ..."    
    Install-PackageProvider -Name Nuget -Force -Scope CurrentUser
}

Write-Host "Checking for required VenafiPS module ..."
$required_venafips_version = 3.1.5
$module_available = Get-Module -ListAvailable -Name VenafiPS | Where-Object { $_.Version -ge $required_venafips_version }
if (-not ($module_available)) {
    Write-Host "Installing VenafiPS module ..."
    Install-Module -Name VenafiPS -MinimumVersion 3.1.5 -Scope CurrentUser -Force
}
else {
    $first_match = $module_available | Select-Object -First 1 
    Write-Host "Found version: $($first_match.Version)"
}

Write-Host "Importing VenafiPS module ..."
Import-Module VenafiPS

# Revoke TPP access token
Write-Host "Revoking access token with $Server"
Revoke-TppToken -AuthServer $Server -AccessToken $AccessToken -Force