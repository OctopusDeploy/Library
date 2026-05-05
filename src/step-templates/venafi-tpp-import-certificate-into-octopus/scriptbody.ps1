[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# TPP required variables
$Server = $OctopusParameters["Venafi.TPP.ImportCert.Server"]
$Token = $OctopusParameters["Venafi.TPP.ImportCert.AccessToken"]
$Path = $OctopusParameters["Venafi.TPP.ImportCert.DNPath"]
$Format = $OctopusParameters["Venafi.TPP.ImportCert.Format"]

# TPP optional variables
$IncludeChain = $OctopusParameters["Venafi.TPP.ImportCert.IncludeChain"]
$FriendlyName = $OctopusParameters["Venafi.TPP.ImportCert.FriendlyName"]
$IncludePrivateKey = $OctopusParameters["Venafi.TPP.ImportCert.IncludePrivateKey"]
$PrivateKeyPassword = $OctopusParameters["Venafi.TPP.ImportCert.PrivateKeyPassword"]
$OutputVariableName = $OctopusParameters["Venafi.TPP.ImportCert.OutputVariableName"]
$RevokeToken = $OctopusParameters["Venafi.TPP.ImportCert.RevokeTokenOnCompletion"]

# Octopus required variables
$OctopusServerUri = $OctopusParameters["Venafi.TPP.ImportCert.OctopusServerUri"]
$OctopusApiKey = $OctopusParameters["Venafi.TPP.ImportCert.OctopusApiKey"]
$OctopusSpaceName = $OctopusParameters["Venafi.TPP.ImportCert.OctopusSpaceName"]
$OctopusCertificateName = $OctopusParameters["Venafi.TPP.ImportCert.OctopusCertificateName"]
$OctopusReplaceExistingCertificate = $OctopusParameters["Venafi.TPP.ImportCert.OctopusReplaceExistingCertificate"]

# TPP validation
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Required parameter Venafi.TPP.ImportCert.Server not specified"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Required parameter Venafi.TPP.ImportCert.AccessToken not specified"
}
if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "Required parameter Venafi.TPP.ImportCert.DNPath not specified"
}
else {
    if ($Path.Contains("\") -eq $False) {
        throw "At least one '\' is required for the Venafi.TPP.ImportCert.DNPath value"
    }
}
if ([string]::IsNullOrWhiteSpace($Format)) {
    throw "Required parameter Venafi.TPP.ImportCert.Format not specified"
}

# TPP conditional validation
if ($IncludePrivateKey -eq $True) {
    if ([string]::IsNullOrWhiteSpace($PrivateKeyPassword)) {
        throw "IncludePrivateKey set to true, but parameter Venafi.TPP.ImportCert.PrivateKeyPassword not specified"
    }
}
else {
    $PrivateKeyPassword = $null
}

# Octopus validation
if ([string]::IsNullOrWhiteSpace($OctopusServerUri)) {
    throw "Required parameter Venafi.TPP.ImportCert.OctopusServerUri not specified"
}
if ([string]::IsNullOrWhiteSpace($OctopusApiKey)) {
    throw "Required parameter Venafi.TPP.ImportCert.OctopusApiKey not specified"
}
if ([string]::IsNullOrWhiteSpace($OctopusSpaceName)) {
    throw "Required parameter Venafi.TPP.ImportCert.OctopusSpaceName not specified"
}
if ([string]::IsNullOrWhiteSpace($OctopusCertificateName)) {
    throw "Required parameter Venafi.TPP.ImportCert.OctopusCertificateName not specified"
}
if ([string]::IsNullOrWhiteSpace($OctopusReplaceExistingCertificate)) {
    throw "Required parameter Venafi.TPP.ImportCert.OctopusReplaceExistingCertificate not specified"
}

# Helper functions
###############################################################################
function Get-WebRequestErrorBody {
    param (
        $RequestError
    )

    # Powershell < 6 you can read the Exception
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($RequestError.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($RequestError.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $rawResponse = $reader.ReadToEnd()
            $response = ""
            try { $response = $rawResponse | ConvertFrom-Json } catch { $response = $rawResponse }
            return $response
        }
    }
    else {
        return $RequestError.ErrorDetails.Message
    }
}

function Get-MatchingOctopusCertificates {
    param (
        [string]$ServerUri,
        [string]$ApiKey,
        [string]$SpaceId,
        [string]$CertificateName
    )
    Write-Debug "Entering: Get-MatchingOctopusCertificates"

    try {

        $header = @{ "X-Octopus-ApiKey" = $ApiKey }

        # Get a list of certificates that match our domain search criteria.
        $partial_certificates = (Invoke-RestMethod -Uri "$ServerUri/api/$SpaceId/certificates?partialName=$([uri]::EscapeDataString($CertificateName))&skip=0&take=2000" -Headers $header) | Select-Object -ExpandProperty Items

        # return certs that arent archived and havent been replaced.
        return $partial_certificates | Where-Object {
            $null -eq $_.ReplacedBy -and
            $null -eq $_.Archived -and 
            $CertificateName -eq $_.Name
        }
    }
    catch {
        $Detail = (Get-WebRequestErrorBody -RequestError $_)
        Write-Error "Could not retrieve certificates from Octopus. Error: $($_.Exception.Message).`n`t$Detail"
    }
}

function Replace-OctopusCertificate {
    param (
        [string]$ServerUri,
        [string]$ApiKey,
        [string]$SpaceId,
        [string]$CertificateId,
        [string]$CertificateName,
        [string]$CertificateData,
        [string]$CertificatePwd
    )
    Write-Debug "Entering: Replace-OctopusCertificate"   
    try {

        $header = @{ "X-Octopus-ApiKey" = $ApiKey }

        $replacement_certificate = @{
            CertificateData = $CertificateData
        }

        if (![string]::IsNullOrWhiteSpace($CertificatePwd)) {
            $replacement_certificate.Password = $CertificatePwd
        }
        
        # Replace the cert
        $updated_certificate = Invoke-RestMethod -Method Post -Uri "$ServerUri/api/$SpaceId/certificates/$CertificateId/replace" -Headers $header -Body ($replacement_certificate | ConvertTo-Json -Depth 10)
        Write-Highlight "Replaced certificate in Octopus for '$($updated_certificate.Name)' ($($updated_certificate.Id))"
    }
    catch {
        $Detail = (Get-WebRequestErrorBody -RequestError $_)
        Write-Error "Could not replace certificate in Octopus. Error: $($_.Exception.Message).`n`t$Detail"
    }
}

function New-OctopusCertificate {
    param (
        [string]$ServerUri,
        [string]$ApiKey,
        [string]$SpaceId,
        [string]$CertificateName,
        [string]$CertificateData,
        [string]$CertificatePwd
    )
    Write-Debug "Entering: New-OctopusCertificate"   
    try {

        $header = @{ "X-Octopus-ApiKey" = $ApiKey }

        $certificate = @{
            Name            = $CertificateName;
            CertificateData = @{
                NewValue = $CertificateData;
                HasData  = $True;
            }
            Password        = @{
                HasValue = $False;
                NewValue = $null;
            }
        }

        if (![string]::IsNullOrWhiteSpace($CertificatePwd)) {
            $certificate.Password.NewValue = $CertificatePwd
            $certificate.Password.HasData = $True
        }
        
        # Create new certificate
        $new_certificate = Invoke-RestMethod -Method Post -Uri "$ServerUri/api/$SpaceId/certificates" -Headers $header -Body ($certificate | ConvertTo-Json -Depth 10)
        Write-Highlight "New certificate created in Octopus for '$($new_certificate.Name)' ($($new_certificate.Id))"
    }
    catch {
        $Detail = (Get-WebRequestErrorBody -RequestError $_)
        Write-Error "Could not create new certificate in Octopus. Error: $($_.Exception.Message).`n`t$Detail"
    }
}

function Clean-VenafiCertificateForOctopus {
    param (
        [string]$CertificateData
    )
    Write-Debug "Entering: Clean-VenafiCertificateForOctopus"   
    $PemHeaderFragment = "-----BEGIN *"
    $PemFooterFragment = "-----END *"

    $CertificateBytes = [Convert]::FromBase64String($CertificateData)
    $RawCert = [System.Text.Encoding]::UTF8.GetString($CertificateBytes)
    
    $CleanedCertLines = @()
    if (![string]::IsNullOrWhiteSpace($RawCert)) {
        $RawCertLines = ($RawCert -Split "`n")
        $currentLine = 0
        while ($currentLine -lt $RawCertLines.Length) {
            Write-Verbose "Working on line $currentLine"
            $headerPosition = [Array]::FindIndex($RawCertLines, $currentLine, [Predicate[string]] { $args[0] -like $PemHeaderFragment })
            if ($headerPosition -gt -1) {
                $footerPosition = [Array]::FindIndex($RawCertLines, $headerPosition, [Predicate[string]] { $args[0] -like $PemFooterFragment })
                if ($footerPosition -lt 0) {
                    throw "Unable to find a matching '-----END' PEM fragment!"
                }
                else {
                    Write-Verbose "Selecting PEM lines: $headerPosition-$footerPosition"
                    $pemLines = $RawCertLines[$headerPosition..$footerPosition]
                    $CleanedCertLines += $pemLines
                    $currentLine = $footerPosition
                }
            }
            else {
                $currentLine++
            }
        }
    }
    if ($CleanedCertLines.Length -le 0) {
        throw "Something went wrong extracting contents from file (no cleansed contents)"
    }

    $CleanedCert = $CleanedCertLines | Out-String
    $CleanedCertData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($CleanedCert))
    
    return $CleanedCertData    
}
###############################################################################
# MAIN STEP TEMPLATE FLOW
###############################################################################

# TPP Access token
$SecureToken = ConvertTo-SecureString $Token -AsPlainText -Force
[PSCredential]$AccessToken = New-Object System.Management.Automation.PsCredential("token", $SecureToken)

# Clean-up
$Server = $Server.TrimEnd('/')
$OctopusServerUri = $OctopusServerUri.TrimEnd('/')
$OctopusSpaceName = $OctopusSpaceName.Trim(" ")
$OctopusCertificateName = $OctopusCertificateName.Trim(" ")

# Required Venafi Module
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
$ExportFormatsIncompatibleWithOctopusCertificateStore = @("Base64", "Base64 (PKCS #8)")

Write-Verbose "Venafi.TPP.ImportCert.Server: $Server"
Write-Verbose "Venafi.TPP.ImportCert.AccessToken: ********"
Write-Verbose "Venafi.TPP.ImportCert.DNPath: $Path"
Write-Verbose "Venafi.TPP.ImportCert.Format: $Format"
Write-Verbose "Venafi.TPP.ImportCert.IncludeChain: $IncludeChain"
Write-Verbose "Venafi.TPP.ImportCert.FriendlyName: $FriendlyName"
Write-Verbose "Venafi.TPP.ImportCert.IncludePrivateKey: $IncludePrivateKey"
Write-Verbose "Venafi.TPP.ImportCert.PrivateKeyPassword: ********"
Write-Verbose "Venafi.TPP.ImportCert.CertDetails.OutputVariableName: $OutputVariableName"
Write-Verbose "Venafi.TPP.ImportCert.RevokeTokenOnCompletion: $RevokeTokenOnCompletion"
Write-Verbose "Venafi.TPP.ImportCert.OctopusServerUri: $OctopusServerUri"
Write-Verbose "Venafi.TPP.ImportCert.OctopusApiKey: ********"
Write-Verbose "Venafi.TPP.ImportCert.OctopusSpaceName: $OctopusSpaceName"
Write-Verbose "Venafi.TPP.ImportCert.OctopusCertificateName: $OctopusCertificateName"
Write-Verbose "Venafi.TPP.ImportCert.OctopusReplaceExistingCertificate: $OctopusReplaceExistingCertificate"
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
    $ExportCert_Params.IncludeChain = $True
}

# Optional FriendlyName field
if (-not [string]::IsNullOrWhiteSpace($FriendlyName)) {
    $ExportCert_Params.FriendlyName = $FriendlyName
}

# Optional Private key field
if (-not [string]::IsNullOrWhiteSpace($PrivateKeyPassword) -and $IncludePrivateKey -eq $True) {
    $SecurePrivateKeyPassword = ConvertTo-SecureString $PrivateKeyPassword -AsPlainText -Force
    $ExportCert_Params.PrivateKeyPassword = $SecurePrivateKeyPassword    
    $ExportCert_Params.IncludePrivateKey = $True
}

# Do the export
$ExportCertificateResponse = ((Export-VenafiCertificate @ExportCert_Params) 6> $null)

if ($null -eq $ExportCertificateResponse -or $null -eq $ExportCertificateResponse.CertificateData) {
    Write-Warning "No certificate data returned for path: $Path`nCheck the path value represents a certificate, and not a folder."
}
else {
    Write-Host "Successfully retrieved certificate data to export for path: $Path"
        
    # Get octopus space Id
    $header = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
    $spaces = Invoke-RestMethod -Uri "$OctopusServerUri/api/spaces?partialName=$([uri]::EscapeDataString($OctopusSpaceName))&skip=0&take=500" -Headers $header 
    $OctopusSpace = @($spaces.Items | Where-Object { $_.Name -eq $OctopusSpaceName }) | Select-Object -First 1

    if ($null -eq $OctopusSpace) {
        throw "Couldnt find Octopus space with name '$OctopusSpaceName'."
    }

    # Check for certificate based on name
    $CertificateMatches = @(Get-MatchingOctopusCertificates -ServerUri $OctopusServerUri -ApiKey $OctopusApiKey -SpaceId $($OctopusSpace.Id) -CertificateName $OctopusCertificateName) 
    Write-Host "Found $($CertificateMatches.Length) certificates matching '$OctopusCertificateName'"

    $FirstCertificateMatch = $CertificateMatches | Select-Object -First 1
    $CertificateData = $ExportCertificateResponse.CertificateData

    if ($ExportFormatsIncompatibleWithOctopusCertificateStore -icontains $Format) {
        Write-Host "Requested export format $Format needs to be cleaned before import to Octopus."
        $CertificateData = Clean-VenafiCertificateForOctopus -CertificateData $CertificateData
        if ([string]::IsNullOrWhiteSpace($CertificateData)) {
            throw "Cleaned certificate data empty!"
        }
    }

    switch ($CertificateMatches.Length) {
        0 {  
            # New cert
            Write-Host "Creating a new certificate '$OctopusCertificateName'"
            New-OctopusCertificate -ServerUri $OctopusServerUri -ApiKey $OctopusApiKey -SpaceId $($OctopusSpace.Id) -CertificateName $OctopusCertificateName -CertificateData $($CertificateData) -CertificatePwd $PrivateKeyPassword
        }
        1 {  
            # One cert to replace
            if ($OctopusReplaceExistingCertificate -eq $False) {
                Write-Host "Replace existing certificate set to False, nothing to do."
            }
            else {
                Write-Host "Replacing existing certificate '$OctopusCertificateName' ($($FirstCertificateMatch.Id))"
                Replace-OctopusCertificate -ServerUri $OctopusServerUri -ApiKey $OctopusApiKey -SpaceId $($OctopusSpace.Id) -CertificateId $($FirstCertificateMatch.Id) -CertificateName $OctopusCertificateName -CertificateData $($CertificateData) -CertificatePwd $PrivateKeyPassword
            }
        }
        default {
            Write-Warning "Multiple certs matching name '$OctopusCertificateName' found, nothing to do."
            return
        }
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