[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$Server = $OctopusParameters["Venafi.TPP.ExportCert.Server"]
$Token = $OctopusParameters["Venafi.TPP.ExportCert.AccessToken"]
$Path = $OctopusParameters["Venafi.TPP.ExportCert.DNPath"]
$Format = $OctopusParameters["Venafi.TPP.ExportCert.Format"]
$OutPath = $OctopusParameters["Venafi.TPP.ExportCert.OutPath"]
$OutFileName = $OctopusParameters["Venafi.TPP.ExportCert.OutFileName"]

# Optional
$IncludeChain = $OctopusParameters["Venafi.TPP.ExportCert.IncludeChain"]
$FriendlyName = $OctopusParameters["Venafi.TPP.ExportCert.FriendlyName"]
$IncludePrivateKey = $OctopusParameters["Venafi.TPP.ExportCert.IncludePrivateKey"]
$PrivateKeyPassword = $OctopusParameters["Venafi.TPP.ExportCert.PrivateKeyPassword"]
$OutputVariableName = $OctopusParameters["Venafi.TPP.ExportCert.OutputVariableName"]
$RevokeToken = $OctopusParameters["Venafi.TPP.ExportCert.RevokeTokenOnCompletion"]

# Validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.ExportCert.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Required parameter Venafi.TPP.ExportCert.AccessToken not specified"
}
if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "Required parameter Venafi.TPP.ExportCert.DNPath not specified"
}
else {
    if ($Path.Contains("\") -eq $False) {
        throw "At least one '\' is required for the Venafi.TPP.ExportCert.DNPath value"
    }
}
if ([string]::IsNullOrWhiteSpace($Format)) {
    throw "Required parameter Venafi.TPP.ExportCert.Format not specified"
}
else {
    if ($Format -eq "JKS") {
        if ([string]::IsNullOrWhiteSpace($PrivateKeyPassword)) {
            throw "Export format is JKS, and parameter Venafi.TPP.ExportCert.PrivateKeyPassword required but not set!"
        }
    }
}
# Conditional validation
if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
    if (-not (Test-Path $OutPath -PathType Container)) {
        throw "Optional parameter Venafi.TPP.ExportCert.OutPath specified but does not exist!"
    }
}
if ($IncludePrivateKey -eq $True) {
    if ([string]::IsNullOrWhiteSpace($PrivateKeyPassword)) {
        throw "IncludePrivateKey set to true, but parameter Venafi.TPP.ExportCert.PrivateKeyPassword not specified"
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

Write-Verbose "Venafi.TPP.ExportCert.Server: $Server"
Write-Verbose "Venafi.TPP.ExportCert.AccessToken: ********"
Write-Verbose "Venafi.TPP.ExportCert.DNPath: $Path"
Write-Verbose "Venafi.TPP.ExportCert.Format: $Format"
Write-Verbose "Venafi.TPP.ExportCert.OutPath: $OutPath"
Write-Verbose "Venafi.TPP.ExportCert.OutFileName: $OutFileName"
Write-Verbose "Venafi.TPP.ExportCert.IncludeChain: $IncludeChain"
Write-Verbose "Venafi.TPP.ExportCert.FriendlyName: $FriendlyName"
Write-Verbose "Venafi.TPP.ExportCert.IncludePrivateKey: $IncludePrivateKey"
Write-Verbose "Venafi.TPP.ExportCert.PrivateKeyPassword: ********"
Write-Verbose "Venafi.TPP.ExportCert.CertDetails.OutputVariableName: $OutputVariableName"
Write-Verbose "Venafi.TPP.ExportCert.RevokeTokenOnCompletion: $RevokeTokenOnCompletion"
Write-Verbose "Step Name: $StepName"

Write-Host "Requesting new session from $Server"
New-VenafiSession -Server $Server -AccessToken $AccessToken

# Export certificate
$ExportCert_Params = @{
    CertificateId = $Path;
    Format        = $Format;
}

# Optional IncludeChain field
if ($IncludeChain -eq $True) {
    if ($Format -eq "JKS") {
        Write-Warning "The IncludeChain parameter is not supported with JKS export format, ignoring."
    }
    else {
        $ExportCert_Params.IncludeChain = $True
    }
}

# Optional FriendlyName field
if (-not [string]::IsNullOrWhiteSpace($FriendlyName)) {
    $ExportCert_Params.FriendlyName = $FriendlyName
}

if (-not [string]::IsNullOrWhiteSpace($PrivateKeyPassword)) {
    $SecurePrivateKeyPassword = ConvertTo-SecureString $PrivateKeyPassword -AsPlainText -Force
    if ($Format -eq "JKS") {
        $ExportCert_Params.KeystorePassword = $SecurePrivateKeyPassword      
    }
    elseif ($IncludePrivateKey -eq $True) {
        $ExportCert_Params.PrivateKeyPassword = $SecurePrivateKeyPassword    
        $ExportCert_Params.IncludePrivateKey = $True
    }
}

$ExportCertificateResponse = ((Export-VenafiCertificate @ExportCert_Params) 6> $null)

if ($null -eq $ExportCertificateResponse -or $null -eq $ExportCertificateResponse.CertificateData) {
    Write-Warning "No certificate data returned for path: $Path`nCheck the path value represents a certificate, and not a folder."
}
else {
    Write-Highlight "Successfully retrieved certificate data to export for path: $Path"
    
    if ([string]::IsNullOrWhiteSpace($OutPath) -eq $False) {
        $Filename = $ExportCertificateResponse.Filename
        if ([string]::IsNullOrWhiteSpace($OutFileName) -eq $False) {
            $Filename = $OutFileName
        }
        $outFile = Join-Path -Path $OutPath -ChildPath ($Filename.Trim('"'))
        $bytes = [Convert]::FromBase64String($ExportCertificateResponse.CertificateData)
        [IO.File]::WriteAllBytes($outFile, $bytes)
        Write-Host ('Saved {0} with format {1}' -f $outFile, $ExportCertificateResponse.Format)
    }
    if ([string]::IsNullOrWhiteSpace($OutputVariableName) -eq $False) {
        $CertificateJson = $ExportCertificateResponse | ConvertTo-Json -Compress -Depth 10 
        Set-OctopusVariable -Name $OutputVariableName -Value $CertificateJson -Sensitive
        Write-Highlight "Created sensitive output variable: ##{Octopus.Action[$StepName].Output.$OutputVariableName}"
    }
}

if ($RevokeToken -eq $true) {
    # Revoke TPP access token
    Write-Host "Revoking access token with $Server"
    Revoke-TppToken -AuthServer $Server -AccessToken $AccessToken -Force
}