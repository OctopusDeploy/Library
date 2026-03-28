$headers = @{
    "Authorization" = "ApiKey $ReleaseNotesHub_ApiKey"
}

$body = @{
    "projectId" = $ReleaseNotesHub_ProjectId;
    "releaseVersion" = $ReleaseNotesHub_Version;
    "associatedProjectId" = $ReleaseNotesHub_AssociatedProjectId;
    "associatedReleaseVersion" = $ReleaseNotesHub_AssociatedVersion      
} | ConvertTo-Json

try {
     Invoke-RestMethod -Method Post -Uri "https://api.releasenoteshub.com/api/releaseassociations/createforversion" -Headers $headers -Body $body -ContentType application/json-patch+json
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    throw $_.Exception
}