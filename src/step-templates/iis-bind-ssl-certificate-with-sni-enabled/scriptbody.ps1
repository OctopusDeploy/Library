$WebsiteName = $OctopusParameters['WebsiteName']
$SSLBindingHost = $OctopusParameters['SSLBindingHost']
$CertificateThumbPrint = $OctopusParameters['CertificateThumbPrint']

new-webbinding -Name $WebsiteName -Protocol "https" -Port 443 -HostHeader $SSLBindingHost -SslFlags 1
netsh http add sslcert hostnameport=$($SSLBindingHost):443 certhash=$CertificateThumbPrint appid='{58ee6009-4e61-400b-80cf-dedc242faf63}' certstorename=MY
