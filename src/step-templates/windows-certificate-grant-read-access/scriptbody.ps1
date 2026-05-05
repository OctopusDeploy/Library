# $certCN is the identifiying CN for the certificate you wish to work with
# The selection also sorts on Expiration date, just in case there are old expired certs still in the certificate store.
# Make sure we work with the most recent cert

Try
{
    $WorkingCert = Get-ChildItem CERT:\LocalMachine\My | where {$_.Subject -match $certCN} | sort $_.NotAfter -Descending | select -first 1 -erroraction STOP
}
Catch
{
    throw "Error: unable to locate certificate for $($CertCN)"
}

$TPrint = $WorkingCert.Thumbprint
if($TPrint)
{
    Write-Host "Found certificate named $certCN with thumbprint $TPrint"
}
else
{
    throw "Error: unable to locate certificate for $($CertCN)"
}

$key = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($WorkingCert)
if ($null -eq $key) {
    throw "Private key not found or unsupported algorithm (non-RSA)."
}

if ($key -is [System.Security.Cryptography.CngKey] -or $key.GetType().Name -eq "RSACng") {
    $rsaFile = $key.Key.UniqueName
    $fullPath = "$($env:ProgramData)\Microsoft\Crypto\Keys\$rsaFile"
} else {
    # Legacy CSP
    $rsaFile = $WorkingCert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
    $fullPath = "$($env:ProgramData)\Microsoft\Crypto\RSA\MachineKeys\$rsaFile"
}

$acl = Get-Acl -Path $fullPath
$permission = $userName,"Read","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.AddAccessRule($accessRule)
Try 
{
    Write-Host "Granting read access for user $userName on $certCN"
    Set-Acl $fullPath $acl
    Write-Host "Success: ACL set on certificate"
}
Catch
{
    throw "Error: unable to set ACL on certificate"
}
