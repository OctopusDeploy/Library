$base64Certificate = $OctopusParameters['Base64Certificate']
$password = $OctopusParameters['Password']
$location = $OctopusParameters['StoreLocation']
$name = $OctopusParameters['StoreName']

Write-Host "Adding/updating certificate in store"

$certBytes = [System.Convert]::FromBase64String($base64Certificate)
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes, $password, "MachineKeySet,PersistKeySet")
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($name, $location)
$store.Open("ReadWrite")
$store.Add($cert)
$store.Close()