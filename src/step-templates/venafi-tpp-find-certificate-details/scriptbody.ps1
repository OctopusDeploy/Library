[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$Server = $OctopusParameters["Venafi.TPP.FindCert.Server"]
$Token = $OctopusParameters["Venafi.TPP.FindCert.AccessToken"]
$SubjectCommonName = $OctopusParameters["Venafi.TPP.FindCert.SubjectCN"]

# Optional 
$CertSerialNumber = $OctopusParameters["Venafi.TPP.FindCert.SerialNumber"]
$Issuer = $OctopusParameters["Venafi.TPP.FindCert.Issuer"]
$ExpireBefore = $OctopusParameters["Venafi.TPP.FindCert.ExpireBefore"]
$OutputVariableName = $OctopusParameters["Venafi.TPP.FindCert.CertDetails.OutputVariableName"]
$RevokeTokenOnCompletion = $OctopusParameters["Venafi.TPP.FindCert.RevokeTokenOnCompletion"]

# Validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.FindCert.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Required parameter Venafi.TPP.FindCert.AccessToken not specified"
}
if ([string]::IsNullOrWhiteSpace($SubjectCommonName)) {
    throw "Required parameter Venafi.TPP.FindCert.SubjectCN not specified"
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

Write-Verbose "Venafi.TPP.FindCert.Server: $Server"
Write-Verbose "Venafi.TPP.FindCert.AccessToken: ********"
Write-Verbose "Venafi.TPP.FindCert.SubjectCN: $SubjectCommonName"
Write-Verbose "Venafi.TPP.FindCert.SerialNumber: $CertSerialNumber"
Write-Verbose "Venafi.TPP.FindCert.Issuer: $Issuer"
Write-Verbose "Venafi.TPP.FindCert.ExpireBefore: $ExpireBefore"
Write-Verbose "Venafi.TPP.FindCert.CertDetails.OutputVariableName: $OutputVariableName"
Write-Verbose "Venafi.TPP.FindCert.RevokeTokenOnCompletion: $RevokeTokenOnCompletion"
Write-Verbose "Step Name: $StepName"

Write-Host "Requesting new session from $Server"
New-VenafiSession -Server $Server -AccessToken $AccessToken

$FindCert_Params = @{
    First      = 5;
    CommonName = $SubjectCommonName;
}

# Optional SerialNumber field
if ([string]::IsNullOrWhiteSpace($CertSerialNumber) -eq $False) {
    $FindCert_Params += @{ SerialNumber = $CertSerialNumber }
}
# Optional Issuer field
if ([string]::IsNullOrWhiteSpace($Issuer) -eq $False) {
    # Issuer DN should be the complete DN enclosed in double quotes. e.g. "CN=Example Root CA, O=Venafi,Inc., L=Salt Lake City, S=Utah, C=US"
    # If a value DN already contains double quotes, the string should be enclosed in a second set of double quotes. 
    if ($Issuer.StartsWith("`"") -or $Issuer.EndsWith("`"")) {
        Write-Verbose "Removing double quotes from start and end of Issuer DN."
        $Issuer = $Issuer.Trim("`"")
    }
    $FindCert_Params += @{ Issuer = "`"$Issuer`"" }
}
# Optional ExpireBefore field
if ([string]::IsNullOrWhiteSpace($ExpireBefore) -eq $False) {
    $FindCert_Params += @{ ExpireBefore = $ExpireBefore }
}

Write-Host "Searching for certificates matching Subject CN: $SubjectCommonName."
$MatchingCertificates = @(Find-TppCertificate @FindCert_Params)
$MatchingCount = $MatchingCertificates.Length
if ($null -eq $MatchingCertificates -or $MatchingCount -eq 0) {
    Write-Warning "No matching certificates found for Subject CN: $SubjectCommonName. Check any additional search criteria and try again."
}
else {
    $MatchingCertificate = $MatchingCertificates | Select-Object -First 1
    if ($MatchingCount -gt 1) {
        Write-Warning "Multiple matching certificates found ($MatchingCount) for Subject CN: $SubjectCommonName, retrieving details for first match."
    }
    
    Write-Highlight "Retrieving certificate details for Subject CN: $SubjectCommonName ($($MatchingCertificate.Path))"
    $Certificate = Get-VenafiCertificate -CertificateId $MatchingCertificate.Path
    if ($null -eq $Certificate) {
        Write-Warning "No certificate details returned for Subject CN: $SubjectCommonName ($($MatchingCertificate.Path))"
    }
    else {
        Write-Host "Retrieved certificate details for Subject CN: $SubjectCommonName ($($MatchingCertificate.Path))"
        $Certificate | Format-List

        if ([string]::IsNullOrWhiteSpace($OutputVariableName) -eq $False) {
            $CertificateJson = $Certificate | ConvertTo-Json -Compress -Depth 10 
            Set-OctopusVariable -Name $OutputVariableName -Value $CertificateJson
            Write-Highlight "Created output variable: ##{Octopus.Action[$StepName].Output.$OutputVariableName}"
        }
    }
}

if ($RevokeTokenOnCompletion -eq $True) {
    # Revoke TPP access token
    Write-Host "Revoking access token with $Server"
    Revoke-TppToken -AuthServer $Server -AccessToken $AccessToken -Force
}