$buildNumber = $OctopusParameters['buildNumber']
$buildTypeId = $OctopusParameters['buildTypeId']

$tcUrl = $OctopusParameters['TeamCityUrl']
$tcUser = $OctopusParameters['TeamCityUser']
$tcPass = $OctopusParameters['TeamCityPassword']
$tcTags = $OctopusParameters['TeamCityTags']

$credentials = [System.Text.Encoding]::UTF8.GetBytes("$($tcUser):$($tcPass)")
$headers = @{ "Authorization" = "Basic $([System.Convert]::ToBase64String($credentials))" }

[string]$tagUri = $tcUrl + ("/app/rest/builds/buildType:{0},number:{1}/tags/" -f $buildTypeId,$buildNumber)

Write-Output "Tagging Build with ID $($id)"

try {
    Invoke-RestMethod -Headers $headers -DisableKeepAlive -Method POST -Uri $tagUri -Body $tcTags -ContentType "text/plain"
    Write-Output "Build ID $($id) tagged successfully"
} catch {
    Write-Output "Build ID $($id) not tagged: $($_.Exception.Message)"
}

