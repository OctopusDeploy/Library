$clientToken = $OctopusParameters['AkamaiClientToken']
$clientAccessToken = $OctopusParameters['AkamaiClientAccessToken']
$clientSecret = $OctopusParameters['AkamaiSecret']
$hostname = $OctopusParameters['AkamaiHostname']
$objects = $OctopusParameters['AkamaiObjects'] -split ","
$action = $OctopusParameters['AkamaiAction']
$domain = $OctopusParameters['AkamaiDomain']
$proxyUser = $OctopusParameters['ProxyUser']
$proxyPassword = $OctopusParameters['ProxyPassword']

if ($proxyUser) {
    $securePassword = ConvertTo-SecureString $proxyPassword -AsPlainText -Force
    $proxyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $proxyUser,$securePassword

    (New-Object System.Net.WebClient).Proxy.Credentials=$proxyCredential
}

# Copied from https://github.com/akamai-open/AkamaiOPEN-powershell/blob/master/Invoke-AkamaiOPEN.ps1
function Invoke-AkamaiOpenRequest {
    param(
        [Parameter(Mandatory=$true)][string]$Method, 
        [Parameter(Mandatory=$true)][string]$ClientToken, 
        [Parameter(Mandatory=$true)][string]$ClientAccessToken, 
        [Parameter(Mandatory=$true)][string]$ClientSecret, 
        [Parameter(Mandatory=$true)][string]$ReqURL, 
        [Parameter(Mandatory=$false)][string]$Body)

    #Function to generate HMAC SHA256 Base64
    Function Crypto ($secret, $message)
    {
	    [byte[]] $keyByte = [System.Text.Encoding]::ASCII.GetBytes($secret)
	    [byte[]] $messageBytes = [System.Text.Encoding]::ASCII.GetBytes($message)
	    $hmac = new-object System.Security.Cryptography.HMACSHA256((,$keyByte))
	    [byte[]] $hashmessage = $hmac.ComputeHash($messageBytes)
	    $Crypt = [System.Convert]::ToBase64String($hashmessage)

	    return $Crypt
    }

    #ReqURL Verification
    If (($ReqURL -as [System.URI]).AbsoluteURI -eq $null -or $ReqURL -notmatch "akamai.com")
    {
	    throw "Error: Ivalid Request URI"
    }

    #Sanitize Method param
    $Method = $Method.ToUpper()

    #Split $ReqURL for inclusion in SignatureData
    $ReqArray = $ReqURL -split "(.*\/{2})(.*?)(\/)(.*)"

    #Timestamp for request signing
    $TimeStamp = [DateTime]::UtcNow.ToString("yyyyMMddTHH:mm:sszz00")

    #GUID for request signing
    $Nonce = [GUID]::NewGuid()

    #Build data string for signature generation
    $SignatureData = $Method + "`thttps`t"
    $SignatureData += $ReqArray[2] + "`t" + $ReqArray[3] + $ReqArray[4]

    if (($Body -ne $null) -and ($Method -ceq "POST"))
    {
	    $Body_SHA256 = [System.Security.Cryptography.SHA256]::Create()
	    $Post_Hash = [System.Convert]::ToBase64String($Body_SHA256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Body.ToString())))

	    $SignatureData += "`t`t" + $Post_Hash + "`t"
    }
    else
    {
	    $SignatureData += "`t`t`t"
    }

    $SignatureData += "EG1-HMAC-SHA256 "
    $SignatureData += "client_token=" + $ClientToken + ";"
    $SignatureData += "access_token=" + $ClientAccessToken + ";"
    $SignatureData += "timestamp=" + $TimeStamp  + ";"
    $SignatureData += "nonce=" + $Nonce + ";"

    #Generate SigningKey
    $SigningKey = Crypto -secret $ClientSecret -message $TimeStamp

    #Generate Auth Signature
    $Signature = Crypto -secret $SigningKey -message $SignatureData

    #Create AuthHeader
    $AuthorizationHeader = "EG1-HMAC-SHA256 "
    $AuthorizationHeader += "client_token=" + $ClientToken + ";"
    $AuthorizationHeader += "access_token=" + $ClientAccessToken + ";"
    $AuthorizationHeader += "timestamp=" + $TimeStamp + ";"
    $AuthorizationHeader += "nonce=" + $Nonce + ";"
    $AuthorizationHeader += "signature=" + $Signature

    #Create IDictionary to hold request headers
    $Headers = @{}

    #Add Auth header
    $Headers.Add('Authorization',$AuthorizationHeader)

    #Add additional headers if POSTing or PUTing
    If (($Method -ceq "POST") -or ($Method -ceq "PUT"))
    {
	    $Body_Size = [System.Text.Encoding]::UTF8.GetByteCount($Body)
	    $Headers.Add('max-body',$Body_Size.ToString())

        # turn off the "Expect: 100 Continue" header
        # as it's not supported on the Akamai side.
        [System.Net.ServicePointManager]::Expect100Continue = $false
    }

    #Check for valid Methods and required switches
    If (($Method -ceq "POST") -and ($Body -ne $null))
    {
        Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers -Body $Body -ContentType 'application/json'
    }
    elseif  (($Method -ceq "PUT") -and ($Body -ne $null))
    {
	    #Invoke API call with PUT and return
	    Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers -Body $Body -ContentType 'application/json'
    }
    elseif (($Method -ceq "GET") -or ($Method -ceq "DELETE"))
    {
	    #Invoke API call with GET or DELETE and return
	    Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers
    }
    else
    {
	    throw "Error: Invalid -Method specified or missing required parameter"
    }
}

function Perform-AkamaiRequest {
    param (
        [string]$request, 
        [string]$method="Get", 
        [int]$expectedStatusCode=200, 
        $body)

    $baseUrl = "http://private-anon-3934daf8d-akamaiopen2purgeccuv3production.apiary-mock.com"
    # $baseUrl = "https://api.ccu.akamai.com"
    $uri = "{0}{1}" -f $baseUrl,$request

    if ($uri -match "mock"){
        $requestHeaders = @{'Cache-Control'='no-cache,proxy-revalidate'}
        $response = Invoke-RestMethod -Uri $uri -Method $method -DisableKeepAlive -Headers $requestHeaders -Body $body
    } else {
        $json = ConvertTo-Json $body -Compress
        $response = Invoke-AkamaiOpenRequest -Method $method -ClientToken $clientToken -ClientAccessToken $clientAccessToken -ClientSecret $clientSecret -ReqURL $uri -Body $json
    }

    if ($response.httpStatus -ne $expectedStatusCode){
        Write-Error "Request not processed correctly: $($response.detail)"
    } elseif ($response.detail) {
        Write-Verbose $response.detail
    }

    Write-Verbose $response

    $response
}

function Request-Purge {
    param ($objects,[string]$hostname,[string]$action="remove",[string]$domain="production")

    $body = @{
        objects = $objects
    }

    if ($hostname -ne $null -and $hostname -ne "") {
        $body = @{
            hostname = $hostname
            objects = $objects
        }
    } 

    Perform-AkamaiRequest "/ccu/v3/$action/$domain" "Post" 201 $body
}

$purge = Request-Purge $objects $hostname $action $domain

Write-Output "Purge request created"
Write-Output "PurgeId: $($purge.purgeId)"
Write-Output "SupportId: $($purge.supportId)" 