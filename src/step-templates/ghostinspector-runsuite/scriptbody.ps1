
$ErrorActionPreference = "Stop" 

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null -or $result -eq "") {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

& {
    param(
		[string]$suiteId,
		[string]$apiKey,
		[string]$siteUrl,
		[string]$httpAuthUser,
		[string]$httpAuthPass
    ) 

	$apiUrl = "https://api.ghostinspector.com/v1/suites/$suiteId/execute/?immediate=1&apiKey=" + $apiKey

	if(-! ([string]::IsNullOrEmpty($siteUrl)))
	{
		$apiUrl = $apiUrl + '&startUrl=' + $siteUrl
	}
	
	if(-! ([string]::IsNullOrEmpty($httpAuthUser) -and [string]::IsNullOrEmpty($httpAuthPass)))
	{
		$apiUrl = $apiUrl + '&httpAuthUsername=' + $httpAuthUser + '&httpAuthPassword=' + $httpAuthPass
	}

	Write-Output "Invoking API url: $apiUrl" 
	
    try {
		Invoke-WebRequest $apiUrl -UseBasicParsing
    } catch [Exception] {
        Write-Host "There was a problem invoking Url"
        Write-Host $_.Exception|format-list -force;
    }
    Write-Output $("Test Output can be viewed here: https://app.ghostinspector.com/suites/{0} -f $suiteId")

 } `
 (Get-Param 'suiteId' -Required) `
 (Get-Param 'apiKey' - Required) `
 (Get-Param 'siteUrl') `
 (Get-Param 'httpAuthUser') `
 (Get-Param 'httpAuthPass')