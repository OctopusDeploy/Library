$clientToken = $OctopusParameters['AkamaiClientToken']
$clientAccessToken = $OctopusParameters['AkamaiClientAccessToken']
$clientSecret = $OctopusParameters['AkamaiSecret']
$cpcode = $OctopusParameters['AkamaiCPCode']
$akhost = $OctopusParameters['AkamaiHost']
$action = $OctopusParameters['AkamaiAction']
$domain = $OctopusParameters['AkamaiDomain']

# NOTICE : PowerShell EdgeGrid Client has been deprecated and will reach End of Life soon. For more information, please see https://developer.akamai.com/blog/2018/11/13/akamai-powershell-edgegrid-client-end-life-notice
# Copied from https://github.com/akamai-open/AkamaiOPEN-powershell/blob/master/Invoke-AkamaiOPEN.ps1
function Invoke-AkamaiOpenRequest {
	param(
		[Parameter(Mandatory=$true)]
		[ValidateSet("GET", "PUT", "POST", "DELETE")]
		[string]$Method,
		[Parameter(Mandatory=$true)][string]$ClientToken,
		[Parameter(Mandatory=$true)][string]$ClientAccessToken,
		[Parameter(Mandatory=$true)][string]$ClientSecret,
		[Parameter(Mandatory=$true)][string]$ReqURL,
		[Parameter(Mandatory=$false)][string]$Body,
		[Parameter(Mandatory=$false)][string]$MaxBody = 131072
		)

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
	If (($ReqURL -as [System.URI]).AbsoluteURI -eq $null -or $ReqURL -notmatch "akamaiapis.net")
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

	#Add body to signature. Truncate if body is greater than max-body (Akamai default is 131072). PUT Medthod does not require adding to signature.
	
	if ($Body -and $Method -eq "POST")
	{
	  $Body_SHA256 = [System.Security.Cryptography.SHA256]::Create()
	  if($Body.Length -gt $MaxBody){
		$Post_Hash = [System.Convert]::ToBase64String($Body_SHA256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Body.Substring(0,$MaxBody))))
	  }
	  else{
		$Post_Hash = [System.Convert]::ToBase64String($Body_SHA256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Body)))
	  }

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
	If ($Body)
	{
	  # turn off the "Expect: 100 Continue" header
	  # as it's not supported on the Akamai side.
	  [System.Net.ServicePointManager]::Expect100Continue = $false
	}
	
	#Check for valid Methods and required switches
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
	if ($Method -eq "PUT" -or $Method -eq "POST") {
		if ($Body) {
			try{
				Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers -Body $Body -ContentType 'application/json'
			}
			catch{
				Write-Host $_ -fore green
			}
		}
		else {
		  Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers -ContentType 'application/json'
		}
	}
	else {
		#Invoke API call with GET or DELETE and return
		Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers
	}
}

function Perform-AkamaiRequest {
    param (
        [string]$request, 
        [string]$method="Get", 
        [int]$expectedStatusCode=200, 
        $body)

    $baseUrl = "https://" + $akhost
    $uri = "{0}{1}" -f $baseUrl,$request

    $json = ConvertTo-Json $body -Compress
    $response = Invoke-AkamaiOpenRequest -Method $method -ClientToken $clientToken -ClientAccessToken $clientAccessToken -ClientSecret $clientSecret -ReqURL $uri -Body $json
	
    if ($response.httpStatus -ne $expectedStatusCode){
        Write-Error "Request not processed correctly: $($response.detail)"
    } elseif ($response.detail) {
        Write-Verbose $response.detail
    }

    $response
}

function Request-Purge {
    param ([Int]$cpcode,[string]$action="remove",[string]$domain="production")

    $body = @{
        objects = @($cpcode)
    }

    Perform-AkamaiRequest "/ccu/v3/$action/cpcode/$domain" "Post" 201 $body
}

$purge = Request-Purge $cpcode $action $domain

Write-Output "Purge request created"
Write-Output "PurgeId: $($purge.purgeId)"
Write-Output "SupportId: $($purge.supportId)" 