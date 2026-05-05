$hostnameport = $OctopusParameters['HostnamePort']
$certhash = $OctopusParameters['CertHash']
$appid = $OctopusParameters['AppId']
$certstore = $OctopusParameters['CertStore']

$delcert = "http delete sslcert hostnameport=""$hostnameport"""
write-host "Removing Cert: $delcert"
$delcert | netsh | out-host

$addcert = "http add sslcert hostnameport=""$hostnameport"" certhash=""$certhash"" appid=""$appid"" certstore=$certstore"
write-host "Creating Certificate Binding: $addcert"
$addcert | netsh | out-host