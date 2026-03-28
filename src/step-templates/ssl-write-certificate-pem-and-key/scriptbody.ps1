
$CertName = $OctopusParameters["sslCertificate.Name"] 
Write-Host "Writing PEM and Key files for $Certname"

New-Item -ItemType directory $sslExportPath -Force -Verbose

"Certificate Pem:"
$pemPath = join-path $sslExportPath $sslPemFile
$OctopusParameters["sslCertificate.CertificatePem"] | out-file $pemPath -Force -Verbose

"-" * 30

"Certificate Key: "
$keypath = join-path $sslExportPath $sslKeyFile
$OctopusParameters["sslCertificate.PrivateKeyPem"] | out-file $keyPath -Force -Verbose
