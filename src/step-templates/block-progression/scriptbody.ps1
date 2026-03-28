$apiKey = $OctopusParameters["Block.Octopus.Api.Key"]
$previousReleaseId = $OctopusParameters["Block.Octopus.Previous.Release.Id"]
$reason = $OctopusParameters["Block.Octopus.Reason"]
$octopusBaseUrl = $OctopusParameters["Block.Octopus.Url"]
$spaceId = $OctopusParameters["Octopus.Space.Id"]

$body = @{
	Description = $reason
}
$bodyAsJson = $body | ConvertTo-JSON -Depth 10

$headers = @{"X-Octopus-ApiKey"="$apiKey"}
    
Write-Host "Blocking the release $previousReleaseId from progressing"
Invoke-RestMethod -Uri "$($octopusBaseUrl)/api/$($spaceId)/releases/$($previousReleaseId)/defects" -Method POST -Headers $headers -Body $bodyAsJSON -ContentType 'application/json; charset=utf-8'