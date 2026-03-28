$url = "$BaseUrl/unicorn.aspx?verb=Sync&configuration=$ConfigName"
Write-Host "Syncing configuration: $ConfigName"
Write-Host "Attempting to invoke: $url"
$deploymentToolAuthToken = $DeploymentAuthToken
$timeout = $Timeout
$basicAuthUser = $BasicAuthUsername
$basicAuthPass = $BasicAuthPassword
$secpasswd = ConvertTo-SecureString $basicAuthPass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($basicAuthUser, $secpasswd)
$result = Invoke-WebRequest -Uri $url -Headers @{ "Authenticate" = $deploymentToolAuthToken } -TimeoutSec $timeout -UseBasicParsing 

Write-Host $result.Content