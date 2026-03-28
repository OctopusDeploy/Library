# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$teamCityBuildConfigId = $OctopusParameters['tcrb_TeamCityBuildConfigurationId']
$teamCityUrl = $OctopusParameters['tcrb_TeamCityUrl']
$teamCityUsername = $OctopusParameters['tcrb_TeamCityUsername']
$teamCityPassword = $OctopusParameters['tcrb_TeamCityPassword']
$teamCityInterval = [int]::Parse($OctopusParameters['tcrb_TeamCityInterval'])
$teamCityBuildParams = $OctopusParameters['tcrb_BuildParams']

function Start-TeamCityBuild($Url, $Username, $Password, $BuildConfigId, $BuildParams) {
    $endpoint = "${Url}/httpAuth/app/rest/buildQueue"
    $content = "<build><buildType id=`"${BuildConfigId}`" /><properties>"
    if (-not [String]::IsNullOrEmpty($BuildParams)) {
        foreach ($param in (ConvertFrom-Csv -Delimiter '=' -Header Name,Value -InputObject $BuildParams)) {
            $name = $param.Name.Replace('"', '&quot;')
            $value = $param.Value.Replace('"', '&quot;')
            $content += "<property name=`"${name}`" value=`"${value}`" />"
        }
    }
    $content += "</properties></build>"    
    $encodedContent = [System.Text.Encoding]::UTF8.GetBytes($content)

    Write-Host "Triggering build with Id ${BuildConfigId} in TeamCity. Server: ${Url}"

    $req = [System.Net.WebRequest]::Create($endpoint)
    $req.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
    $req.Method = "POST"
    $req.ContentType = "application/xml"

    $req.ContentLength = $encodedContent.length
    $requestStream = $req.GetRequestStream()
    $requestStream.Write($encodedContent, 0, $encodedContent.length)
    $requestStream.Close()

    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $result = [xml]$reader.ReadToEnd()
    $buildUrl = $result.build.webUrl

    Write-Host $buildUrl
    Write-Host "================================================================================"

    return $result
}

function Get-TeamCityBuildState($Url, $Username, $Password, $BuildInfo) {
    $href = $BuildInfo.href
    $buildId = $BuildInfo.id
    $endpoint = "${Url}${href}"

    Write-Host "Getting state of build ${buildId} in TeamCity. Server: ${Url}"

    $req = [System.Net.WebRequest]::Create($endpoint)
    $req.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
    $req.Method = "GET"

    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    return [xml]$reader.ReadToEnd();
}

function Invoke-TeamCityBuild ($Url, $Username, $Password, $BuildConfigId, $Interval, $BuildParams) {
    $build = Start-TeamCityBuild -Url $Url -Username $Username -Password $Password -BuildConfigId $BuildConfigId -BuildParams $teamCityBuildParams
    $buildInfo = $build.build

    while ($true) {
        $buildState = Get-TeamCityBuildState -Url $teamCityUrl -Username $teamCityUsername -Password $teamCityPassword -BuildInfo $buildInfo
        Write-Host $buildState.build.state
        if ($buildState.build.state -eq 'finished') {
            return $buildState.build
        }
        
        Start-Sleep -Seconds $Interval
    }
}

$buildResult = Invoke-TeamCityBuild -Url $teamCityUrl -Username $teamCityUsername -Password $teamCityPassword -BuildConfigId $teamCityBuildConfigId -Interval $teamCityInterval -BuildParams $teamCityBuildParams
$message = $buildResult.statusText
Write-Host "================================================================================"
Write-Host $buildResult.webUrl
if ($buildResult.status -eq 'FAILURE') {
    Write-Host "Build failed: ${message}"
    exit 1
}
elseif ($message -eq 'Canceled') {
    Write-Host "Build canceled: ${message}"
    exit 2
}
else {
    Write-Host "Build successful: ${message}"
    exit 0
}
