$apiKey = $OctopusParameters['ElmahIoSourceMap_ApiKey']
$logId = $OctopusParameters['ElmahIoSourceMap_LogId']
$path = $OctopusParameters['ElmahIoSourceMap_Path']
$sourceMap = $OctopusParameters['ElmahIoSourceMap_SourceMap']
$minifiedJavaScript = $OctopusParameters['ElmahIoSourceMap_MinifiedJavaScript']
$boundary = [System.Guid]::NewGuid().ToString()

$mapFile = [System.IO.File]::ReadAllBytes($sourceMap)
$mapContent = [System.Text.Encoding]::UTF8.GetString($mapFile)
$mapFileName = Split-Path $sourceMap -leaf
$jsFile = [System.IO.File]::ReadAllBytes($minifiedJavaScript)
$jsContent = [System.Text.Encoding]::UTF8.GetString($jsFile)
$jsFileName = Split-Path $minifiedJavaScript -leaf

$LF = "`r`n"
$bodyLines = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"Path`"$LF",
    $path,
    "--$boundary",
    "Content-Disposition: form-data; name=`"SourceMap`"; filename=`"$mapFileName`"",
    "Content-Type: application/json$LF",
    $mapContent,
    "--$boundary",
    "Content-Disposition: form-data; name=`"MinifiedJavaScript`"; filename=`"$jsFileName`"",
    "Content-Type: text/javascript$LF",
    $jsContent,
    "--$boundary--$LF"
) -join $LF

Invoke-RestMethod "https://api.elmah.io/v3/sourcemaps/${logId}?api_key=${apiKey}" -Method POST -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines