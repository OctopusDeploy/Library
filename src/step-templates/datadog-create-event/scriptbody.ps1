# Lets handle our own errors here
$ErrorActionPreference = "continue"

$apiKey = $OctopusParameters['ApiKey']
$title = $OctopusParameters['EventTitle']
$body = $OctopusParameters['EventBody']
$alertType = $OctopusParameters['AlertType']
$priority = $OctopusParameters['Priority']
$tags = $OctopusParameters['Tags']
$endpoint = $OctopusParameters['DatadogEndpoint']
$eventsApiEndpoint = "/api/v1/events"

# Write out some debug information
Write-Host "Event Title: $title"
Write-Host "Event Body: $body"
Write-Host "Alert Type: $alertType"
Write-Host "Priority: $priority"
Write-Host "Tags: $tags"
Write-Host "Datadog Endpoint: $endpoint$eventsApiEndpoint"

# Create the url from basic information
$url = "$endpoint$eventsApiEndpoint`?api_key=$apiKey"
$tagString = [system.String]::Join("`",`"", $tags.Split(","))

$json = @"
{
      "title": "$title",
      "text": "$body",
      "priority": "$priority",
      "tags": ["$tagString"],
      "alert_type": "$alertType"
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
if($response.StatusCode -ne 202){
    Write-Error "There was an error listing response content below to debug"
    $response.RawContent
}else{
    Write-Host "Sent Successfully"
}

# We usually don't want to fail a deployment because of this
EXIT 0