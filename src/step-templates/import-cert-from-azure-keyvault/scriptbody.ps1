Import-Module AzureRM.Profile
Import-Module AzureRM.KeyVault

Function Validate-Parameter($parameterValue, [string[]]$validInput, $parameterName) {
    Write-Host "${parameterName}: ${parameterValue}"
    if (! $parameterValue) {
        throw "$parameterName cannot be empty, please specify a value"
    }
}

Function Install-AzureKeyVaultCertificate {
    Param(
        [string]$keyVaultName,
        [string]$certificateName,
        [string]$certificateVersion,
        [string]$certificateStoreName,
        [string]$certificateStoreLocation,
        [string]$certificateFriendlyName
    )
    
    Write-Output "Retrieving '$certificateName' from '$keyVaultName' ..."
    $getSecretParams = @{
    	VaultName = $keyVaultName
        Name = $certificateName
    }

	if($certificateVersion -notmatch "latest") {
        $getSecretParams["Version"] = $certificateVersion
    }
    
	$cert = Get-AzureKeyVaultSecret @getSecretParams
    $b64 = [System.Convert]::FromBase64String($cert.SecretValueText)
    $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($b64, "", "MachineKeySet,PersistKeySet")
    Write-Output "Certificate information:"
    Write-Output ($pfx | fl | Out-String)
    
    $certPath = "Cert:\$certificateStoreLocation\$certificateStoreName\$($pfx.Thumbprint)"
    if (Test-Path $certPath) {
        "A certificate with thumbprint '$($pfx.Thumbprint)' appears to already exist in the certificate store. Skipping..."
    }
    else {
        Write-Output "Opening certificate store '$certificateStoreName' in '$certificateStoreLocation' ..."
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($certificateStoreName, $certificateStoreLocation)
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

		if($certificateFriendlyName) {
          Write-Output "Setting certificate friendly name to '$certificateFriendlyName'..."
          $pfx.FriendlyName = $certificateFriendlyName
		}
        
        Write-Output "Adding certificate..."
        $store.Add($pfx)
        $store.Close()
        Write-Output "Certificate added."

        Write-Output "Verifying - searching certificate store for thumbprint '$($pfx.Thumbprint)'..."
        if (Test-Path $certPath) {
            Write-Output "Certificate is successfully imported!"
        }
        else {
            Write-Error "ERROR: Certificate with thumbprint '$($pfx.Thumbprint)' was not found in certificate store '$certificateStoreName' in '$certificateStoreLocation'"
        }
    }
}

$azureSubscriptionId = $OctopusParameters['Azure.GetKeyVaultCertificate.SubscriptionId']
$azureTenantId = $OctopusParameters['Azure.GetKeyVaultCertificate.TenantId']
$azureClientId = $OctopusParameters['Azure.GetKeyVaultCertificate.ClientId']
$azurePassword = $OctopusParameters['Azure.GetKeyVaultCertificate.Password']
$keyVaultName = $OctopusParameters['Azure.GetKeyVaultCertificate.KeyVaultName']
$certificateName = $OctopusParameters['Azure.GetKeyVaultCertificate.CertificateName']
$certificateVersion = $OctopusParameters['Azure.GetKeyVaultCertificate.CertificateVersion']
$certificateStoreName = $OctopusParameters['Azure.GetKeyVaultCertificate.CertificateStoreName']
$certificateStoreLocation = $OctopusParameters['Azure.GetKeyVaultCertificate.CertificateStoreLocation']
$certificateFriendlyName = $OctopusParameters['Azure.GetKeyVaultCertificate.CertificateFriendlyName']

# Validate that all parameters have values
Write-Output "Validating parameters..."
Validate-Parameter $azureSubscriptionId -parameterName "azureSubscriptionId"
Validate-Parameter $azureTenantId -parameterName "azureTenantId"
Validate-Parameter $azureClientId -parameterName "azureClientId"
Validate-Parameter $azurePassword -parameterName "azurePassword"
Validate-Parameter $keyVaultName -parameterName "keyVaultName"
Validate-Parameter $certificateName -parameterName "certificateName"
Validate-Parameter $certificateVersion -parameterName "certificateVersion"
Validate-Parameter $certificateStoreName -parameterName "certificateStoreName"
Validate-Parameter $certificateStoreLocation -parameterName "certificateStoreLocation"

$azureCreds = New-Object System.Management.Automation.PSCredential($azureClientId, (ConvertTo-SecureString -String $azurePassword -AsPlainText -Force))
Login-AzureRmAccount -ServicePrincipal -SubscriptionId $azureSubscriptionId -TenantId $azureTenantId -Credential $azureCreds

$params = @{
    keyVaultName             = $keyVaultName
    certificateName          = $certificateName
    certificateVersion       = $certificateVersion
    certificateStoreName     = $certificateStoreName
    certificateStoreLocation = $certificateStoreLocation
    certificateFriendlyName     = $certificateFriendlyName
}

Install-AzureKeyVaultCertificate @params