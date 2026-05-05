[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$StepName = $OctopusParameters["Octopus.Step.Name"]
$Server = $OctopusParameters["Venafi.TPP.OAuthToken.Server"]
$ClientID = $OctopusParameters["Venafi.TPP.OAuthToken.ClientID"]
$Username = $OctopusParameters["Venafi.TPP.OAuthToken.Username"]
$Password = $OctopusParameters["Venafi.TPP.OAuthToken.Password"]
$Scopes = $OctopusParameters["Venafi.TPP.OAuthToken.Scope"]

# Validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.OAuthToken.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($ClientID)) {
    throw "Required parameter Venafi.TPP.OAuthToken.ClientID not specified"
}
if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "Required parameter Venafi.TPP.OAuthToken.Username not specified"
}
if ([string]::IsNullOrWhiteSpace($Password)) {
    throw "Required parameter Venafi.TPP.OAuthToken.Password not specified"
}
if ([string]::IsNullOrWhiteSpace($Scopes)) {
    throw "Required parameter Venafi.TPP.OAuthToken.Scope not specified"
}

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

$AccessTokenScope = @{}

$Scopes -Split ";" | ForEach-Object {
    $Scope = ($_ -Split ":")
    $Type = $Scope[0]
    $Privileges = $null
    
    if ($Scope.Length -gt 1) {
        $Privileges = $Scope[1].TrimEnd(",")
    }
    
    if ($AccessTokenScope.ContainsKey($Type)) {
        $CurrentPrivileges = $AccessTokenScope[$Type]
        # If no privilege, set to $null
        if ([string]::IsNullOrWhiteSpace($Privileges)) {
            $AccessTokenScope[$Type] = $null
        }
        else {
            $AccessTokenScope[$Type] = if ([string]::IsNullOrWhiteSpace($CurrentPrivileges)) { $Privileges } else { "$($CurrentPrivileges),$Privileges" }  
        }
    }
    else {
        $AccessTokenScope.Add($Type, $Privileges)
    }
}

if ($AccessTokenScope.Keys.Count -lt 1) {
    throw "No scopes could be determined!"
}

$scopeString = @($AccessTokenScope.GetEnumerator() | ForEach-Object { if ($_.Value) { '{0}:{1}' -f $_.Key, $_.Value } else { $_.Key } }) -join ';'

# Get TPP access token
[PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))

Write-Host "Requesting new OAuth token from: $Server for ClientId: $ClientID with scope '$scopeString' ..."
$tppTokenResponse = New-TppToken -AuthServer $Server -ClientId $ClientID -Scope $AccessTokenScope -Credential $Credential

$AccessToken = $tppTokenResponse.AccessToken.GetNetworkCredential().Password
$Expiry = $tppTokenResponse.Expires.ToString("s")
$RefreshToken = $tppTokenResponse.RefreshToken.GetNetworkCredential().Password
$RefreshExpires = $tppTokenResponse.RefreshExpires

# Refresh Expiry can be $null
if ($null -ne $RefreshExpires) {
    $RefreshExpires = $RefreshExpires.ToString("s")
}

Set-OctopusVariable -Name "AccessToken" -Value $AccessToken -Sensitive
Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.AccessToken}"
Set-OctopusVariable -Name "AccessTokenExpires" -Value $Expiry -Sensitive
Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.AccessTokenExpires}"
Set-OctopusVariable -Name "RefreshToken" -Value $RefreshToken -Sensitive
Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.RefreshToken}"
Set-OctopusVariable -Name "RefreshTokenExpires" -Value $RefreshExpires -Sensitive
Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.RefreshTokenExpires}"