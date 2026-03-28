if ( -not [string]::IsNullOrEmpty( $ReleaseNotesHub_Version ) )
{
	$v = $ReleaseNotesHub_Version
}
else
{
	$v = $OctopusParameters['Octopus.Release.Number']
}

$headers = @{
    "Authorization" = "ApiKey $ReleaseNotesHub_ApiKey"
}

$body = @{
    "name" = $ReleaseNotesHub_Name;
    "version" = $v;
    "createOnNotFound" = $ReleaseNotesHub_CreateOnNotFound;
    "IgnoreIfExists" = $ReleaseNotesHub_IgnoreIfExists;
    "publish" = $ReleaseNotesHub_Publish     
} | ConvertTo-Json

try {
     Invoke-RestMethod -Method Post -Uri "https://api.releasenoteshub.com/api/pull/PullVersion/$ReleaseNotesHub_ProjectId" -Headers $headers -Body $body -ContentType application/json-patch+json
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    throw $_.Exception
}