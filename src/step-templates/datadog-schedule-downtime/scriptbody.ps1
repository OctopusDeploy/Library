# Lets handle our own errors here
$ErrorActionPreference = "continue"

$apiKey = $OctopusParameters['ApiKey']
$appKey = $OctopusParameters['AppKey']
$endpoint = $OctopusParameters['DatadogEndpoint']
$downtimeApiEndpoint = "/api/v1/downtime"
$scope = $OctopusParameters['Environment']
$durstring = $OctopusParameters['Duration']

[int]$duration = [convert]::ToInt32($durstring,10)

# Write out some debug information
Write-Host "Scheduling Downtime for: $scope"
Write-Host "Datadog Endpoint: $endpoint$downtimeApiEndpoint"

# Create the url from basic information
$url = "$endpoint$downtimeApiEndpoint`?api_key=$apiKey&application_key=$appKey"

Write-Host $url

$start=[Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))
$end = $start + $duration
$json = @"
{
      "scope": "env:$scope",
      "start": "$start",
      "end": "$end"
  }
"@

# Make the response and handle exceptions **Requires PS 3.0 + 
try {
    $response = Invoke-WebRequest -Uri $url -Method POST -Body ($json | ConvertFrom-Json | ConvertTo-Json) -ContentType "Application/json" -UseBasicParsing
}catch{
    Write-Error "Error: $_"
    EXIT 0
}

# Some Error handling here
if($response.StatusCode -ne 200){
    Write-Error "There was an error listing response content below to debug"
    $response.RawContent
}else{
    Write-Host "Sent Successfully"
}

# We usually don't want to fail a deployment because of this
EXIT 0