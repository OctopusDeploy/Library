[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'
# Variables
$Server = $OctopusParameters["Venafi.TPP.CreateCert.Server"]
$Token = $OctopusParameters["Venafi.TPP.CreateCert.AccessToken"]
$CertPath = $OctopusParameters["Venafi.TPP.CreateCert.DNPath"]
$CertName = $OctopusParameters["Venafi.TPP.CreateCert.Name"]
$CertCommonName = $OctopusParameters["Venafi.Tpp.CreateCert.SubjectCN"]
# Optional
$CertCAPath = $OctopusParameters["Venafi.Tpp.CreateCert.CertificateAuthorityDN"]
$CertType = $OctopusParameters["Venafi.Tpp.CreateCert.Type"]
$CertManagementType = $OctopusParameters["Venafi.Tpp.CreateCert.ManagementType"]
$CertSubjectAltNames = $OctopusParameters["Venafi.Tpp.CreateCert.SubjectAltNames"]
$CertProvisionWait = $OctopusParameters["Venafi.TPP.CreateCert.ProvisioningWait"]
$CertProvisionTimeout = $OctopusParameters["Venafi.TPP.CreateCert.ProvisioningTimeout"]
$ApplicationPath = $OctopusParameters["Venafi.TPP.CreateCert.ApplicationPath"]
$ApplicationPush = $OctopusParameters["Venafi.TPP.CreateCert.PushCertificate"]
$RevokeToken = $OctopusParameters["Venafi.TPP.CreateCert.RevokeTokenOnCompletion"]
# Validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.CreateCert.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Required parameter Venafi.TPP.CreateCert.AccessToken not specified"
}
if ([string]::IsNullOrWhiteSpace($CertPath)) {
    throw "Required parameter Venafi.TPP.CreateCert.DNPath not specified"
}
if ([string]::IsNullOrWhiteSpace($CertName)) {
    throw "Required parameter Venafi.TPP.CreateCert.Name not specified"
}
if ([string]::IsNullOrWhiteSpace($CertCommonName)) {
    throw "Required parameter Venafi.TPP.CreateCert.SubjectCN not specified"
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
Write-Host "Requesting new session from $Server"
New-VenafiSession -Server $Server -AccessToken $AccessToken
# New certificate
$NewCert_Params = @{
    Path       = $CertPath;
    Name       = $CertName;
    CommonName = $CertCommonName
}
# Optional CertificateType field
if (-not [string]::IsNullOrWhiteSpace($CertType)) {
    $NewCert_Params.CertificateType = $CertType
}
# Optional CertificateAuthorityPath field
if (-not [string]::IsNullOrWhiteSpace($CertCAPath)) {
    $NewCert_Params.CertificateAuthorityPath = $CertCAPath
}
# Optional ManagementType field
if (-not [string]::IsNullOrWhiteSpace($CertManagementType)) {
    $NewCert_Params.ManagementType = $CertManagementType
}
# Optional SubjectAltName field
if (-not [string]::IsNullOrWhiteSpace($CertSubjectAltNames)) {
    $SubjectAltNames = @()
    $SubjectAltNameStrings = $CertSubjectAltNames -split "`n"
    foreach ($SubjectAltNameString in $SubjectAltNameStrings) {
        if (-not [string]::IsNullOrWhiteSpace($SubjectAltNameString)) {
            $ReplacedString = $SubjectAltNameString.Trim().Replace(";", "`n")
            $StringAsHash = $ReplacedString | ConvertFrom-StringData
            $SubjectAltNames += $StringAsHash
        }
    }
    $NewCert_Params.SubjectAltName = $SubjectAltNames
}
# Generate New Certificate
Write-Host "Creating certificate '$CertName' ($CertPath)..."
$NewCertificate = New-TppCertificate @NewCert_Params -PassThru
$count = 0
$Continue = $True
# Wait for certificate provisioning
if ($CertProvisionWait -eq $true -and $CertManagementType -eq "Provisioning") {
    $EndWait = (Get-Date).AddSeconds($CertProvisionTimeout)
    do {
        if ($count -gt 0) { 
            Write-Host "Waiting 30 seconds for certificate to provision..."
            Start-Sleep -Seconds 30
        }
        $count++
        Write-Host "Checking certificate provisioning status."
        $CertDetails = Get-VenafiCertificate -CertificateId $NewCertificate.Path
        Write-Verbose "ProcessingDetails: $($CertDetails.ProcessingDetails)"
        if (-not "$($CertDetails.ProcessingDetails)") {
            $Continue = $False
            Write-Host "Successful certificate provisioning detected."
        }
        elseif ($CertDetails.ProcessingDetails.InError -eq $True -or $CertDetails.ProcessingDetails.Status -eq "Failure") {
            $Continue = $False
            Write-Error "Certificate failed to provision at Stage: $($CertDetails.ProcessingDetails.Stage), Status: $($CertDetails.ProcessingDetails.Status)"
        }
    } until ($Continue -eq $False -or (Get-Date) -ge $EndWait)
}
# Associate Certificate with application
if (-not [string]::IsNullOrWhiteSpace($ApplicationPath)) {
    $ApplicationPathArray = @()
    if ($ApplicationPath.Contains(",")) {
        $ApplicationPathArray = $ApplicationPath.Split(",")
    }
    else {
        $ApplicationPathArray += $ApplicationPath
    }

    if ($CertProvisionWait -eq $false) {
    	Write-Warning "Associating the certificate $CertName with  application(s) at path(s) ($ApplicationPath) may be ongoing as waiting for provisioning is set to False. This could result in a failed association."
    }

    if ($ApplicationPush -eq $true) {
        Write-Host "Associating and pushing certificate to application at $ApplicationPath"
        Add-TppCertificateAssociation -CertificatePath $NewCertificate.Path -ApplicationPath $ApplicationPathArray -PushCertificate
    }
    else {
        Write-Host "Associating certificate to application at $ApplicationPath"
        Add-TppCertificateAssociation -CertificatePath $NewCertificate.Path -ApplicationPath $ApplicationPathArray
    }
}
if ($RevokeToken -eq $true) {
    # Revoke TPP access token
    Write-Host "Revoking access token with $Server"
    Revoke-TppToken -AuthServer $Server -AccessToken $AccessToken -Force
}