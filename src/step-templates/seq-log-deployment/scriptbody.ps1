function Open-Seq ([string] $url, [string] $apiKey, $properties = @{})
{
  return @{ Url = $url; ApiKey = $apiKey; Properties = $properties.Clone() }
}
  
function Send-SeqEvent (
    $seq,
    [string] $text,
    [string] $level,
    $properties = @{},
    [string] $exception = $null,
    [switch] $template)
{
  if (-not $level) {
    $level = 'Information'
  }
   
  if (@('Verbose', 'Debug', 'Information', 'Warning', 'Error', 'Fatal') -notcontains $level) {
    $level = 'Information'
  }
  
  $allProperties = $seq["Properties"].Clone()
  $allProperties += $properties
  
  $messageTemplate = "{Text}"
  
  if ($template) {
    $messageTemplate = $text;
  } else {
    $allProperties += @{ Text = $text; }
  }
  
  $exceptionProperty = ""
  if ($exception) {
      $exceptionProperty = """Exception"": $($exception | ConvertTo-Json),"
  }
  
  $body = "{""Events"": [ {
    ""Timestamp"": ""$([System.DateTimeOffset]::Now.ToString('o'))"",
    ""Level"": ""$level"",
    $exceptionProperty
    ""MessageTemplate"": $($messageTemplate | ConvertTo-Json),
    ""Properties"": $($allProperties | ConvertTo-Json) }]}"
  
  $target = "$($seq["Url"])/api/events/raw?apiKey=$($seq["ApiKey"])"
  
  Invoke-RestMethod -Uri $target -Body $body -ContentType "application/json" -Method POST
}

Write-Output "Logging the deployment result to Seq at $SeqServerUrl..."

$seq = Open-Seq $SeqServerUrl -apiKey $SeqApiKey

$properties = @{
    ProjectName = $OctopusParameters['Octopus.Project.Name'];
    ReleaseNumber = $OctopusParameters['Octopus.Release.Number'];
    Result = "succeeded";
    EnvironmentName = $OctopusParameters['Octopus.Environment.Name'];
    DeploymentName = $OctopusParameters['Octopus.Deployment.Name'];
    Channel = $OctopusParameters['Octopus.Release.Channel.Name'];
    DeploymentLink = $OctopusParameters['#{if Octopus.Web.ServerUri}Octopus.Web.ServerUri#{else}Octopus.Web.BaseUrl#{/if}'] + $OctopusParameters['Octopus.Web.DeploymentLink']
}

$level = "Information"
$exception = $null
if ($OctopusParameters['Octopus.Deployment.Error']) {
    $level = "Error"
    $properties["Result"] = "failed"
    $properties["Error"] = $OctopusParameters['Octopus.Deployment.Error']
    $exception = $OctopusParameters['Octopus.Deployment.ErrorDetail']
}

try {
    Send-SeqEvent $seq "A deployment of {ProjectName} release {ReleaseNumber} {Result} in {EnvironmentName}" -level $level -template -properties $properties -exception $exception
} catch [Exception] {
    [System.Console]::Error.WriteLine("Unable to write deployment details to Seq")
    $_.Exception | format-list -force
}
