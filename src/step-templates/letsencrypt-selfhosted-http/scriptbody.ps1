# TLS 1.2
Write-Host "Enabling TLS 1.2 for script execution"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

###############################################################################
# Required Modules folder
###############################################################################
Write-Host "Checking for required powershell modules folder"
$ModulesFolder = "$HOME\Documents\WindowsPowerShell\Modules"
if ($PSEdition -eq "Core") {
    if ($PSVersionTable.Platform -eq "Unix") {
        $ModulesFolder = "$HOME/.local/share/powershell/Modules"
    }
    else {
        $ModulesFolder = "$HOME\Documents\PowerShell\Modules"
    }
}
$PSModuleFolderExists = (Test-Path $ModulesFolder)
if ($PSModuleFolderExists -eq $False) {
	Write-Host "Creating directory: $ModulesFolder"
	New-Item $ModulesFolder -ItemType Directory -Force
    $env:PSModulePath = $ModulesFolder + [System.IO.Path]::PathSeparator + $env:PSModulePath
}

###############################################################################
# Required Modules
###############################################################################
Write-Host "Checking for required modules."
$required_posh_acme_version = 3.12.0
$module_check = Get-Module -ListAvailable -Name Posh-Acme | Where-Object { $_.Version -ge $required_posh_acme_version }

if (-not ($module_check)) {
    Write-Host "Ensuring NuGet provider is bootstrapped."
    Get-PackageProvider NuGet -ForceBootstrap | Out-Null
    Write-Host "Installing Posh-ACME."
    Install-Module -Name Posh-ACME -MinimumVersion 3.12.0 -Scope CurrentUser -Force
}

Write-Host "Importing Posh-ACME"
Import-Module Posh-ACME

# Variables
$LE_SelfHosted_CertificateDomain = $OctopusParameters["LE_SelfHosted_CertificateDomain"]
$LE_SelfHosted_Contact = $OctopusParameters["LE_SelfHosted_ContactEmailAddress"]
$LE_SelfHosted_PfxPass = $OctopusParameters["LE_SelfHosted_PfxPass"]
$LE_SelfHosted_Use_Staging = $OctopusParameters["LE_SelfHosted_Use_Staging"]
$LE_SelfHosted_HttpListenerTimeout = $OctopusParameters["LE_SelfHosted_HttpListenerTimeout"]
$LE_Self_Hosted_UpdateOctopusCertificateStore = $OctopusParameters["LE_Self_Hosted_UpdateOctopusCertificateStore"]
$LE_SelfHosted_Octopus_APIKey = $OctopusParameters["LE_SelfHosted_Octopus_APIKey"]
$LE_SelfHosted_ReplaceIfExpiresInDays = $OctopusParameters["LE_SelfHosted_ReplaceIfExpiresInDays"]
$LE_SelfHosted_Install = $OctopusParameters["LE_SelfHosted_Install"]
$LE_SelfHosted_ExportFilePath = $OctopusParameters["LE_SelfHosted_ExportFilePath"]
$LE_SelfHosted_Export = -not [System.String]::IsNullOrWhiteSpace($LE_SelfHosted_ExportFilePath)
$LE_SelfHosted_TempFileLocation=[System.IO.Path]::GetTempFileName()

# Consts
$LE_SelfHosted_Certificate_Name = "Lets Encrypt - $LE_SelfHosted_CertificateDomain"

# Issuer used in a cert could be one of multiple, including ones no longer supported by Let's Encrypt
$LE_SelfHosted_Fake_Issuers = @("Fake LE Intermediate X1", "(STAGING) Artificial Apricot R3", "(STAGING) Ersatz Edamame E1", "(STAGING) Pseudo Plum E5", "(STAGING) False Fennel E6", "(STAGING) Puzzling Parsnip E7", "(STAGING) Mysterious Mulberry E8", "(STAGING) Fake Fig E9", "(STAGING) Counterfeit Cashew R10", "(STAGING) Wannabe Watercress R11", "(STAGING) Riddling Rhubarb R12", "(STAGING) Tenuous Tomato R13", "(STAGING) Not Nectarine R14")
$LE_SelfHosted_Issuers = @("Let's Encrypt Authority X3", "E1", "E2", "E7", "E8", "R3", "R4", "R5", "R6", "R10", "R11", "R12", "R13")

# Helper(s)
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
            $response = $reader.ReadToEnd()
            return $response | ConvertFrom-Json
        }
    }
    else {
        return $RequestError.ErrorDetails.Message
    }
}

function Clean-TempFiles {
	if(Test-Path -Path $LE_SelfHosted_TempFileLocation) {
		Write-Debug "Removing temporary file..."
		Remove-Item $LE_SelfHosted_TempFileLocation -Force
	}
}

function Exit-Failure {
  	Clean-TempFiles
	Exit 1
}

function Exit-Success {
  	Clean-TempFiles
	Exit 0
}

# Functions
function Get-LetsEncryptCertificate {
    Write-Debug "Entering: Get-LetsEncryptCertificate"

    if ($LE_SelfHosted_Use_Staging -eq $True) {
        Write-Host "Using Lets Encrypt Server: Staging"
        Set-PAServer LE_STAGE;
    }
    else {
        Write-Host "Using Lets Encrypt Server: Production"
        Set-PAServer LE_PROD;
    }

    $le_account = Get-PAAccount
    if ($le_account) {
        Write-Host "Removing existing PA-Account..."
        Remove-PAAccount $le_account.Id -Force
    }
    
    Write-Host "Assigning new PA-Account..."
    $le_account = New-PAAccount -Contact $LE_SelfHosted_Contact -AcceptTOS -Force
    
    Write-Host "Requesting new order for $LE_SelfHosted_CertificateDomain..."
    $order = New-PAOrder -Domain $LE_SelfHosted_CertificateDomain -PfxPass $LE_SelfHosted_PfxPass -Force
    
    try {
    	Write-Host "Invoking Self-Hosted HttpChallengeListener with timeout of $LE_SelfHosted_HttpListenerTimeout seconds..."
    	Invoke-HttpChallengeListener -Verbose -ListenerTimeout $LE_SelfHosted_HttpListenerTimeout
        	
        Write-Host "Getting validated certificate..."
        $pArgs = @{ManualNonInteractive=$True}
        $cert = New-PACertificate $LE_SelfHosted_CertificateDomain -PluginArgs $pArgs
        
        if ($LE_SelfHosted_Install -eq $True) {
        	if (-not $IsWindows -and 'Desktop' -ne $PSEdition) {
              Write-Host "Installing certificate currently only works on Windows"
          	}
            else {
              Write-Host "Installing certificate to local store..."
              $cert | Install-PACertificate
            }
    	}
        
        # Linux showed weird $null issues using the .PfxFullChain path
        if(Test-Path -Path $LE_SelfHosted_TempFileLocation) {
        	Write-Debug "Creating temp copy of certificate to: $LE_SelfHosted_TempFileLocation"
        	$bytes = [System.IO.File]::ReadAllBytes($cert.PfxFullChain)
            New-Item -Path $LE_SelfHosted_TempFileLocation -ItemType "file" -Force
            [System.IO.File]::WriteAllBytes($LE_SelfHosted_TempFileLocation, $bytes)
        }
        
        if($LE_SelfHosted_Export -eq $True) {
        	Write-Host "Exporting certificate to: $LE_SelfHosted_ExportFilePath"
        	$bytes = [System.IO.File]::ReadAllBytes($LE_SelfHosted_TempFileLocation)
            New-Item -Path $LE_SelfHosted_ExportFilePath -ItemType "file" -Force
            [System.IO.File]::WriteAllBytes($LE_SelfHosted_ExportFilePath, $bytes)
    	}

        return $cert
    }
    catch {
        Write-Host "Failed to Create Certificate. Error Message: $($_.Exception.Message). See Debug output for details."
        Write-Debug (Get-WebRequestErrorBody -RequestError $_)
        Exit-Failure
    }
}

function Get-OctopusCertificates {
    Write-Debug "Entering: Get-OctopusCertificates"

    $octopus_uri = $OctopusParameters["Octopus.Web.ServerUri"]
    $octopus_space_id = $OctopusParameters["Octopus.Space.Id"]
    $octopus_headers = @{ "X-Octopus-ApiKey" = $LE_SelfHosted_Octopus_APIKey }
    $octopus_certificates_uri = "$octopus_uri/api/$octopus_space_id/certificates?search=$LE_SelfHosted_CertificateDomain"

    try {
        # Get a list of certificates that match our domain search criteria.
        $certificates_search = Invoke-WebRequest -Uri $octopus_certificates_uri -Method Get -Headers $octopus_headers -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty Items

        # We don't want to confuse Production and Staging Lets Encrypt Certificates.
        $possible_issuers = $LE_SelfHosted_Issuers
        if ($LE_SelfHosted_Use_Staging -eq $True) {
            $possible_issuers = $LE_SelfHosted_Fake_Issuers
        }

        return $certificates_search | Where-Object {
            $_.SubjectCommonName -eq $LE_SelfHosted_CertificateDomain -and
            $possible_issuers -contains $_.IssuerCommonName -and
            $null -eq $_.ReplacedBy -and
            $null -eq $_.Archived
        }
    }
    catch {
        Write-Host "Could not retrieve certificates from Octopus Deploy. Error: $($_.Exception.Message). See Debug output for details."
        Write-Debug (Get-WebRequestErrorBody -RequestError $_)
        Exit-Failure
    }
}

function Publish-OctopusCertificate {
    param (
        [string] $JsonBody
    )

    Write-Debug "Entering: Publish-OctopusCertificate"

    if (-not ($JsonBody)) {
        Write-Host "Existing Certificate Id and a replace Certificate are required."
        Exit-Failure
    }

    $octopus_uri = $OctopusParameters["Octopus.Web.ServerUri"]
    $octopus_space_id = $OctopusParameters["Octopus.Space.Id"]
    $octopus_headers = @{ "X-Octopus-ApiKey" = $LE_SelfHosted_Octopus_APIKey }
    $octopus_certificates_uri = "$octopus_uri/api/$octopus_space_id/certificates"
	Write-Verbose "Preparing to publish to: $octopus_certificates_uri"
    
    try {
        Invoke-WebRequest -Uri $octopus_certificates_uri -Method Post -Headers $octopus_headers -Body $JsonBody -UseBasicParsing
        Write-Host "Published $LE_SelfHosted_CertificateDomain certificate to the Octopus Deploy Certificate Store."
    }
    catch {
        Write-Host "Failed to publish $LE_SelfHosted_CertificateDomain certificate. Error: $($_.Exception.Message). See Debug output for details."
        Write-Debug (Get-WebRequestErrorBody -RequestError $_)
        Exit-Failure
    }
}

function Update-OctopusCertificate {
    param (
        [string]$Certificate_Id,
        [string]$JsonBody
    )

    Write-Debug "Entering: Update-OctopusCertificate"

    if (-not ($Certificate_Id -and $JsonBody)) {
        Write-Host "Existing Certificate Id and a replace Certificate are required."
        Exit-Failure
    }

    $octopus_uri = $OctopusParameters["Octopus.Web.ServerUri"]
    $octopus_space_id = $OctopusParameters["Octopus.Space.Id"]
    $octopus_headers = @{ "X-Octopus-ApiKey" = $LE_SelfHosted_Octopus_APIKey }
    $octopus_certificates_uri = "$octopus_uri/api/$octopus_space_id/certificates/$Certificate_Id/replace"

    try {
        Invoke-WebRequest -Uri $octopus_certificates_uri -Method Post -Headers $octopus_headers -Body $JsonBody -UseBasicParsing
        Write-Host "Replaced $LE_SelfHosted_CertificateDomain certificate in the Octopus Deploy Certificate Store."
    }
    catch {
        Write-Error "Failed to replace $LE_SelfHosted_CertificateDomain certificate. Error: $($_.Exception.Message). See Debug output for details."
        Write-Debug (Get-WebRequestErrorBody -RequestError $_)
        Exit-Failure
    }
}

function Get-NewCertificatePFXAsJson {
    param (
        $Certificate
    )

    Write-Debug "Entering: Get-NewCertificatePFXAsJson"

    if (-not ($Certificate)) {
        Write-Host "Certificate is required."
        Exit-Failure
    }

    [Byte[]]$certificate_buffer = [System.IO.File]::ReadAllBytes($LE_SelfHosted_TempFileLocation)
    $certificate_base64 = [convert]::ToBase64String($certificate_buffer)

    $certificate_body = @{
        Name = "$LE_SelfHosted_CertificateDomain";
        Notes            = "";
        CertificateData  = @{
            HasValue = $true;
            NewValue = $certificate_base64;
        };
        Password         = @{
            HasValue = $true;
            NewValue = $LE_SelfHosted_PfxPass;
        };
    }

    return $certificate_body | ConvertTo-Json
}

function Get-ReplaceCertificatePFXAsJson {
    param (
        $Certificate
    )

    Write-Debug "Entering: Get-ReplaceCertificatePFXAsJson"

    if (-not ($Certificate)) {
        Write-Host "Certificate is required."
        Exit-Failure
    }

    [Byte[]]$certificate_buffer = [System.IO.File]::ReadAllBytes($LE_SelfHosted_TempFileLocation)
    $certificate_base64 = [convert]::ToBase64String($certificate_buffer)

    $certificate_body = @{
        CertificateData = $certificate_base64;
        Password        = $LE_SelfHosted_PfxPass;
    }

    return $certificate_body | ConvertTo-Json
}

# Main Execution starts here

Write-Debug "Running MAIN function..."

if ($LE_Self_Hosted_UpdateOctopusCertificateStore -eq $True) {
  Write-Host "Checking for existing Lets Encrypt Certificates in the Octopus Deploy Certificates Store..."
  $certificates = Get-OctopusCertificates

  # Check for PFX & PEM
  if ($certificates) {

      # Handle behavior between Powershell 5 and Powershell 6+
      $certificate_count = 1
      if ($certificates.Count -ge 1) {
          $certificate_count = $certificates.Count
      }

      Write-Host "Found $certificate_count for $LE_SelfHosted_CertificateDomain."
      Write-Host "Checking to see if any expire within $LE_SelfHosted_ReplaceIfExpiresInDays days."

      # Check Expiry Dates
      $expiring_certificates = $certificates | Where-Object { [DateTime]$_.NotAfter -lt (Get-Date).AddDays($LE_SelfHosted_ReplaceIfExpiresInDays) }

      if ($expiring_certificates) {
          Write-Host "Found certificates that expire with $LE_SelfHosted_ReplaceIfExpiresInDays days. Requesting new certificates for $LE_SelfHosted_CertificateDomain from Lets Encrypt"
          $le_certificate = Get-LetsEncryptCertificate

          # PFX
          $existing_certificate = $certificates | Where-Object { $_.CertificateDataFormat -eq "Pkcs12" } | Select-Object -First 1
          $certificate_as_json = Get-ReplaceCertificatePFXAsJson -Certificate $le_certificate
          Update-OctopusCertificate -Certificate_Id $existing_certificate.Id -JsonBody $certificate_as_json
      }
      else {
          Write-Host "Nothing to do here..."
      }

	Write-Host "Completed running..."
    Exit-Success
  }
}

Write-Host "Requesting New Certificate for $LE_SelfHosted_CertificateDomain from Lets Encrypt"

$le_certificate = Get-LetsEncryptCertificate

if($LE_Self_Hosted_UpdateOctopusCertificateStore -eq $True) {
  Write-Host "Publishing new LetsEncrypt - $LE_SelfHosted_CertificateDomain (PFX) to Octopus Certificate Store"
  $certificate_as_json = Get-NewCertificatePFXAsJson -Certificate $le_certificate
  Publish-OctopusCertificate -JsonBody $certificate_as_json
} 
else {
  Write-Host "Certificate generated..."
  $le_certificate | fl
}

Write-Host "Completed running..."
Exit-Success