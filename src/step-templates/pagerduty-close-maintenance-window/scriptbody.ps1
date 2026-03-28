param(
    [string]$OpeningStepName = "",
    [string]$Token = ""
) 

function Get-Param($Name, [switch]$Required, $Default) {
    $Result = $null

    if ($OctopusParameters -ne $null) {
        $Result = $OctopusParameters[$Name]
    }

    if ($Result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($variable -ne $null) {
            $Result = $variable.Value
        }
    }

    if ($Result -eq $null -or $Result -eq "") {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $Result = $Default
        }
    }

    return $Result
}

& {
    param([string]$OpeningStepName, [string]$Token)

	$WindowId = $OctopusParameters["Octopus.Action[$OpeningStepName].Output.WindowId"]
    $Uri = "https://api.pagerduty.com/maintenance_windows/$WindowId"
    $Headers = @{
          "Authorization" = "Token token=$Token"
          "Accept" = "application/vnd.pagerduty+json;version=2"
		}

	try {
		Invoke-RestMethod -Uri $Uri -Method Delete -ContentType "application/json" -Headers $Headers
		Write-Host "PagerDuty window closed for window_id: $WindowId"
	} catch [System.Exception] {
        Write-Host $_.Exception.Message
        
        $ResponseStream = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($ResponseStream)
        $Reader.ReadToEnd() | Write-Host

		Exit 0
    }
} (Get-Param 'OpeningStepName' -Required) (Get-Param 'Token' -Required)