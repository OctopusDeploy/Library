$buildConfId = $OctopusParameters['BuildConfigurationId']

$teamCityUrl = $OctopusParameters['TeamCityUrl']
$teamCityUsername = $OctopusParameters['TeamCityUsername']
$teamCityPassword = $OctopusParameters['TeamCityPassword']

$url = $teamCityUrl + '/httpAuth/app/rest/buildQueue'
$contentTemplate = '<build><buildType id="{0}"/></build>'
$content = $contentTemplate -f $buildConfId
$encodedContent = [System.Text.Encoding]::UTF8.GetBytes($content)

Write-Host "================================================================================"
Write-Host "Triggering build with Id $buildConfId in TeamCity. Server:" $teamCityUrl 
Write-Host "================================================================================"

$req = [System.Net.WebRequest]::Create($url)
$req.Credentials = new-object System.Net.NetworkCredential($teamCityUsername, $teamCityPassword)
$req.Method ="POST"
$req.ContentType = "application/xml"

$req.ContentLength = $encodedContent.length
$requestStream = $req.GetRequestStream()
$requestStream.Write($encodedContent, 0, $encodedContent.length)
$requestStream.Close()

$resp = $req.GetResponse()
$reader = new-object System.IO.StreamReader($resp.GetResponseStream())
$reader.ReadToEnd() | Write-Host
