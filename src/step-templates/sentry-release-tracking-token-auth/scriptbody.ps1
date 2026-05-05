$organization = $OctopusParameters["SentryReleaseTracking.organization"]
$projects = $OctopusParameters["SentryReleaseTracking.projects"]
$apiToken = $OctopusParameters["SentryReleaseTracking.apiToken"]

$url = "https://sentry.io/api/0/organizations/$organization/releases/"
Write-Host $url

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $apiToken")
$body = ConvertTo-Json @{ 
	"version" = $OctopusParameters['Octopus.Release.Number']
    "projects" = $projects.Split(";")
}

Write-Host $body
Try
{
	$response = Invoke-RestMethod -Method Post -Uri "$url" -Body $body -Headers $headers -ContentType "application/json"
	Write-Host $response
}
Catch { 
	if($_.Exception.Response.StatusCode -ne 400)
	{
  		Throw $_
    }
}
