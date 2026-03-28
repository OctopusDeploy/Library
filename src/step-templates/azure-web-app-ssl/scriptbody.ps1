<#
Takes an Octopus certificate variable and
    1) Writes it to a temporary file with a password (as Azure requires the PFX have a password)
    2) Invokes New-AzureRmWebAppSSLBinding
    3) Removes the temporary certificate file
#>

$ErrorActionPreference = 'Stop'

Write-Verbose "Creating temporary certificate file"
$TempCertificateFile = New-TemporaryFile
# The PFX upload to Azure must have a password. So we give it a GUID.
$Password = [guid]::NewGuid().ToString("N")

$CertificateName = $OctopusParameters["SslCertificate.Name"]

Write-Host "Creating HTTPS binding on web app '$SslWebApp' for domain $SslDomainName using certificate '$CertificateName' "

$CertificateBytes = [Convert]::FromBase64String($OctopusParameters["SslCertificate.Pfx"])
[IO.File]::WriteAllBytes($TempCertificateFile.FullName, $CertificateBytes)
Get-PfxData -FilePath $TempCertificateFile.FullName | Export-PfxCertificate -FilePath $TempCertificateFile.FullName -Password (ConvertTo-SecureString -String $Password -AsPlainText -Force)

$BindingParams = @{
    WebAppName = $SslWebApp
    ResourceGroupName = $SslResourceGroup
    Name = $SslDomainName
    CertificateFilePath = $TempCertificateFile.FullName
    CertificatePassword = $Password
    SslState = $SslState
}

if ($SslSlot) { $BindingParams['Slot'] = $SslSlot }

New-AzureRmWebAppSSLBinding @BindingParams

Write-Verbose "Removing temporary certificate file"
Remove-Item $TempCertificateFile.FullName -Force