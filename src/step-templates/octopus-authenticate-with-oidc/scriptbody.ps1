function Invoke-OctopusApi {
  param(
    $Uri,
    $Method,
    $Body
  )

  try {
    Write-Verbose "Making request to $Uri"

    if ($null -eq $Body)
    {
      Write-Verbose "No body to send in the request"
      return Invoke-RestMethod -Method $method -Uri $Uri -ContentType "application/json; charset=utf-8"
    } 

  $Body = $Body | ConvertTo-Json -Depth 10
  Write-Verbose $Body
  
    return Invoke-RestMethod -Uri $Uri -Method $Method -Body $Body -ContentType "application/json; charset=utf-8" -ErrorAction Stop
  }
  catch {
    Write-Host "Request failed with message `"$($_.Exception.Message)`""

    if ($_.Exception.Response) {
        $code = $_.Exception.Response.StatusCode.value__
        $message = $_.Exception.Message
        Write-Host "HTTP response code: $code"

        Write-Host "Server returned: $error"
      }

    Fail-Step "Failed to make $method request to $uri"
  }
}

if ([string]::IsNullOrWhiteSpace($OctopusParameters["AuthenticateWithOIDC.ServerUri"])) {
  Fail-Step "Octopus Server Uri is required."
}

if ([string]::IsNullOrWhiteSpace($OctopusParameters["AuthenticateWithOIDC.OidcAccount"])) {
  Fail-Step "OIDC Account is required."
}

$server = $OctopusParameters["AuthenticateWithOIDC.ServerUri"]
$serviceAccountId = $OctopusParameters["AuthenticateWithOIDC.OidcAccount.Audience"]
$jwt = $OctopusParameters["AuthenticateWithOIDC.OidcAccount.OpenIdConnect.Jwt"]

$body = @{
  grant_type = "urn:ietf:params:oauth:grant-type:token-exchange";
  audience = "$serviceAccountId";
  subject_token_type = "urn:ietf:params:oauth:token-type:jwt";
  subject_token = "$jwt"
}

$uri = "$server/.well-known/openid-configuration"
$response = Invoke-OctopusApi -Uri $uri -Method "GET"
$response = Invoke-OctopusApi -Uri $response.token_endpoint -Method "POST" -Body $body

Set-OctopusVariable -name "AccessToken" -value $response.access_token -sensitive

$stepName = $OctopusParameters["Octopus.Step.Name"]
Write-Host "Created output variable: ##{Octopus.Action[$stepName].Output.AccessToken}"