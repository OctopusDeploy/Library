$buildNumber = $OctopusParameters['buildNumber']
$buildTypeId = $OctopusParameters['buildTypeId']

$tcUrl = $OctopusParameters['TeamCityUrl']
$tcUser = $OctopusParameters['TeamCityUser']
$tcPass = $OctopusParameters['TeamCityPassword']

[string]$tcRestUrl = $tcUrl + '/httpAuth/app/rest/builds/buildType:{1},number:{0}/pin/'
$url = $tcRestUrl -f $buildNumber,$buildTypeId

Write-Host "****************************"
Write-Host "Pinning build in TeamCity at:"$url 
Write-Host "****************************"

$req = [System.Net.WebRequest]::Create($url)
$req.Credentials = new-object System.Net.NetworkCredential($tcUser, $tcPass)
$req.Method ="PUT"
$req.ContentLength = 0

$resp = $req.GetResponse()
$reader = new-object System.IO.StreamReader($resp.GetResponseStream())
$reader.ReadToEnd() | Write-Host
