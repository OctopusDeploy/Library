$webclient = New-Object System.Net.WebClient
$webclient.Credentials = New-Object System.Net.NetworkCredential($UserName, $Password)
$webClient.Headers.add('App-Key',$AppKey)
$url = "https://api.pingdom.com/api/2.0/checks/$CheckId"
$actionBody = "paused=" + ($Action -eq "Pause").tostring().tolower()

$checkResult = $webclient.DownloadString($url) | ConvertFrom-Json
Write-Host "Attempting to" $Action.tolower() "check" $CheckId "-" $checkResult.check.name

$result = $webclient.UploadString($url, "PUT", $actionBody) | ConvertFrom-Json

Write-Host $result.message