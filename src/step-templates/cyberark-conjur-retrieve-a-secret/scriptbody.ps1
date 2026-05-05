# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function CreateUriWithoutIncorrectSlashEncoding {
    param(
        [Parameter(Mandatory)][string]$uri
    )
    $newUri = New-Object System.Uri $uri
    [void]$newUri.PathAndQuery # need to access PathAndQuery (presumably modifies internal state)
    $flagsFieldInfo = $newUri.GetType().GetField("m_Flags", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $flags = $flagsFieldInfo.GetValue($newUri)
    $flags = $flags -band (-bnot 0x30) # remove Flags.PathNotCanonical|Flags.QueryNotCanonical (private enum)
    $flagsFieldInfo.SetValue($newUri, $flags)
    $newUri
}

$CONJUR_APPLIANCE_URL = "#{CONJUR_APPLIANCE_URL}"
$CONJUR_ACCOUNT = "#{CONJUR_ACCOUNT}"
$CONJUR_AUTHN_LOGIN = "#{CONJUR_AUTHN_LOGIN}"
$CONJUR_AUTHN_API_KEY = "#{CONJUR_AUTHN_API_KEY}"
$VARIABLE_ID = "#{CONJUR_VARIABLE_ID}"

$encodedLogin = ($CONJUR_AUTHN_LOGIN).Replace("/","%2F")
$encodedPath = ($VARIABLE_ID).Replace("/","%2F")

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Accept-Encoding", "base64")

$body = $CONJUR_AUTHN_API_KEY

$url1 = "$CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/$encodedLogin/authenticate"
if ("#{CONJUR_FIX_SLASH_ENCODING}" -eq "True")  { $url1 = CreateUriWithoutIncorrectSlashEncoding "$url1" }

$response = Invoke-RestMethod -uri $url1  -Method 'POST' -Headers $headers -Body $body -UseBasicParsing

$token="Token token=""$($response)"""

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "$token")

$url2 = CreateUriWithoutIncorrectSlashEncoding "$CONJUR_APPLIANCE_URL/secrets/$CONJUR_ACCOUNT/variable/$encodedPath"
if ("#{CONJUR_FIX_SLASH_ENCODING}" -eq "True") { $url2 = CreateUriWithoutIncorrectSlashEncoding "$url2" }

$secretvalue = Invoke-RestMethod $url2 -Method 'GET' -Headers $headers   -UseBasicParsing

$sensitiveOutputVariablesSupported = ((Get-Command 'Set-OctopusVariable').Parameters.GetEnumerator() | Where-Object { $_.key -eq "Sensitive" }) -ne $null
if ($sensitiveOutputVariablesSupported -and ("#{CONJUR_STAY_SENSITIVE}" -eq "True")) {
	Set-OctopusVariable -name "#{CONJUR_OUTPUT_NAME}" -value $secretvalue -sensitive
} else {
	Set-OctopusVariable -name "#{CONJUR_OUTPUT_NAME}" -value $secretvalue
}