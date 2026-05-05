[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-OctopusCertificates {
    Write-Debug "Entering: Get-OctopusCertificates"

    $octopus_uri = $OctopusParameters["Certificate.Expiry.Check.OctopusServerUrl"].Trim('/')
    $octopus_space_id = $OctopusParameters["Octopus.Space.Id"]
    $octopus_headers = @{ "X-Octopus-ApiKey" = $OctopusParameters["Certificate.Expiry.Check.ApiKey"] }
    $octopus_certificates_uri = "$octopus_uri/api/$octopus_space_id/certificates?search=$($OctopusParameters["Certificate.Expiry.Check.CertificateDomain"])"

    try {
        # Get a list of certificates that match our domain search criteria.
        $certificates_search = Invoke-WebRequest -Uri $octopus_certificates_uri -Method Get -Headers $octopus_headers -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty Items

        return $certificates_search | Where-Object {
            $null -eq $_.ReplacedBy -and
            $null -eq $_.Archived
        }
    }
    catch {
        Write-Host "Could not retrieve certificates from Octopus Deploy. Error: $($_.Exception.Message)."
        exit 1
    }
}

Write-Host "Checking for existing certificates in the Octopus Deploy Certificates Store."
$certificates = Get-OctopusCertificates

if ($certificates) {

    # Handle weird behavior between Powershell 5 and Powershell 6+
    $certificate_count = 1
    if ($certificates.Count -ge 1) {
        $certificate_count = $certificates.Count
    }

    Write-Host "Found $certificate_count matching domain: $($OctopusParameters["Certificate.Expiry.Check.CertificateDomain"])."
    Write-Host "Checking to see if any expire within $($OctopusParameters["Certificate.Expiry.Check.Days"]) days."

    # Check Expiry Dates
    $expiring_certificates = $certificates | Where-Object { [DateTime]$_.NotAfter -lt (Get-Date).AddDays($OctopusParameters["Certificate.Expiry.Check.Days"]) }

    if ($expiring_certificates) {
        Write-Host "Found certificates that expire with $($OctopusParameters["Certificate.Expiry.Check.Days"]) days."
        
        $expiring_certs_json = $expiring_certificates | select Name, Thumbprint, SubjectCommonName, Issuer, NotAfter | ConvertTo-Json
        Set-OctopusVariable -name "ExpiringCertificateJson" -value $expiring_certs_json

    }
    else {
    	Set-OctopusVariable -name "ExpiringCertificateJson" -value ""
        Write-Host "Nothing to do here..."
    }

    exit 0
}
