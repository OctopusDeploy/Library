$Name = "HTTP to HTTPS Redirect (Octopus Deploy)"
$PsPath = "MACHINE/WEBROOT/APPHOST"
$Filter = "system.webserver/rewrite/GlobalRules"

Clear-WebConfiguration -pspath $PsPath -filter "$Filter/rule[@name='$Name']"
if ($Site) {
    $Filter = "system.webserver/rewrite/rules"
    Clear-WebConfiguration -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']"
}

if ($Disabled -eq "true") {
    exit
}

#Clear-WebConfiguration -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']"
Add-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter" -name "." -value @{name=$Name; patternSyntax='ECMAScript'; stopProcessing='True'}
Set-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']/match" -name url -value "(.*)"
Add-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']/conditions" -name "." -value @{input="{HTTPS}"; pattern='^OFF$'}
if ($EnableProxyRules -eq "true") {
    Add-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']/conditions" -name "." -value @{input="{HTTP_X_FORWARDED_PROTO}"; pattern='^HTTP$'}
}

Set-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']/action" -name "type" -value "Redirect"
Set-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']/action" -name "url" -value "https://{HTTP_HOST}/{R:1}"
Set-WebConfigurationProperty -location $Site -pspath $PsPath -filter "$Filter/rule[@name='$Name']/action" -name "redirectType" -value "Permanent" 