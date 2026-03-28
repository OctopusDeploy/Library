[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$Server = $OctopusParameters["Venafi.TPP.GetCert.Server"]
$Token = $OctopusParameters["Venafi.TPP.GetCert.AccessToken"]
$Path = $OctopusParameters["Venafi.TPP.GetCert.DNPath"]

# Optional
$OutputVariableName = $OctopusParameters["Venafi.TPP.GetCert.OutputVariableName"]
$RevokeToken = $OctopusParameters["Venafi.TPP.GetCert.RevokeTokenOnCompletion"]

# Validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.GetCert.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Required parameter Venafi.TPP.GetCert.AccessToken not specified"
}
if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "Required parameter Venafi.TPP.GetCert.DNPath not specified"
}
else {
    if ($Path.Contains("\") -eq $False) {
        throw "At least one '\' is required for the Venafi.TPP.GetCert.DNPath value"
    }
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

$StepName = $OctopusParameters["Octopus.Step.Name"]

# Create Venafi session
New-VenafiSession -Server $Server -AccessToken $AccessToken

# Retrieve certificate details
$CertificateDetails = Get-VenafiCertificate -CertificateId $Path | Select-Object -First 1

if ($null -eq $CertificateDetails -or $null -eq $CertificateDetails.Path) {
    Write-Warning "No certificate details returned for path: $Path`nCheck the path value represents a certificate, and not a folder."
}
else {
    Write-Highlight "Retrieved certificate details for path: $Path"
    $CertificateDetails | Format-List
    
    if ([string]::IsNullOrWhiteSpace($OutputVariableName) -eq $False) {
        $CertificateJson = $CertificateDetails | ConvertTo-Json -Compress -Depth 10 
        Set-OctopusVariable -Name $OutputVariableName -Value $CertificateJson
        Write-Highlight "Created output variable: ##{Octopus.Action[$StepName].Output.$OutputVariableName}"
    }
}

if ($RevokeToken -eq $true) {
    # Revoke TPP access token
    Write-Host "Revoking access token with $Server"
    Revoke-TppToken -AuthServer $Server -AccessToken $AccessToken -Force
}