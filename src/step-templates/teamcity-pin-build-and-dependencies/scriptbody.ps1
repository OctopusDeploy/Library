$buildNumber = $OctopusParameters['buildNumber']
$buildTypeId = $OctopusParameters['buildTypeId']

$tcUrl = $OctopusParameters['TeamCityUrl']
$tcUser = $OctopusParameters['TeamCityUser']
$tcPass = $OctopusParameters['TeamCityPassword']
$tcComments = $OctopusParameters['TeamCityPinComment']
$tcTags = $OctopusParameters['TeamCityTags']

$credentials = [System.Text.Encoding]::UTF8.GetBytes("$($tcUser):$($tcPass)")
$headers = @{ "Authorization" = "Basic $([System.Convert]::ToBase64String($credentials))" }

[string]$restUri = $tcUrl + ("/httpAuth/app/rest/builds/?locator=buildType:{1},branch:default:any,number:{0}" -f $buildNumber,$buildTypeId)

$response = Invoke-RestMethod -Headers $headers -DisableKeepAlive -Method GET -Uri $restUri

if ($response -ne $null -and $response.builds.count -eq 1) {
    $id = $response.builds.build.id
    
    [string]$pinUri = $tcUrl + ("/ajax.html?pinComment={1}&pin=true&buildId={0}&buildTagsInfo={2}&applyToChainBuilds=true" -f $id,$tcComments,$tcTags)

    Write-Output "Pinning Build with ID $($id)"

    try {
        Invoke-RestMethod -Headers $headers -DisableKeepAlive -Method POST -Uri $pinUri
        Write-Output "Build ID $($id) pinned successfully"
    } catch {
        Write-Output "Build ID $($id) not pinned: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Build not found, unable to pin"
}
