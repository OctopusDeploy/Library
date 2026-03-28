$httpAction = 'POST'

if ($WebJobAction -eq 'delete') {
    $httpAction = 'DELETE'
}

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $WebJobUserName,$WebJobPassword)))
$apiUrl = "https://$WebJobWebApp.scm.azurewebsites.net/api/$WebJobType/$WebJobName/$WebJobAction"
Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method $httpAction -ContentType "Application/Json"