param(
    [array]$ServiceIds = @(""),
    [string]$RequesterId = "",
    [string]$Description = "",
    [int]$Minutes = 10,
    [string]$Token = ""
) 

$ErrorActionPreference = "Stop" 

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
    param([array]$ServiceIds, [string]$RequesterId, [string]$Description, [int]$Minutes, [string]$Token)

    Write-Host "Opening PagerDuty window for $Description"

    try {
        $ArrayOfServices = $ServiceIds.split(",") | foreach { $_.trim() }
        $Start = ((Get-Date)).ToString("yyyy-MM-ddTHH:mm:sszzzzZ");
        $End = ((Get-Date).AddMinutes($Minutes)).ToString("yyyy-MM-ddTHH:mm:sszzzzZ");
        $ServiceIdArray = @()
        
        foreach($ServiceId in $ArrayOfServices){
        	$ServiceIdArray += @{"id"=$ServiceId; "type"="service_reference"}
        }
        
        $Uri = "https://api.pagerduty.com/maintenance_windows"
        $Headers = @{
          "Authorization" = "Token token=$Token"
          "Accept" = "application/vnd.pagerduty+json;version=2"
          "From" = $RequesterId
		}

        Write-Host "Window will be open from $Start -> $End"

        $Post = @{
            maintenance_window= @{
            	type = 'maintenance_window'
                start_time = $Start
                end_time = $End
                description = $Description
                services = $ServiceIdArray
            }
        } | ConvertTo-Json -Depth 4

        $ResponseObj = Invoke-RestMethod -Uri $Uri -Method Post -Body $Post -ContentType "application/json" -Headers $Headers
        $WindowId = $ResponseObj.maintenance_window.id

        Write-Host "Window Id $WindowId created"

        if(Get-Command -name "Set-OctopusVariable" -ErrorAction SilentlyContinue) {
            Set-OctopusVariable -name "WindowId" -value $WindowId
        } else {
            Write-Host "Octopus output variable not set"
        }
    } catch [System.Exception] {
        Write-Host "Error while opening PagerDuty window"
        Write-Host $_.Exception.Message
        
        $ResponseStream = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($ResponseStream)
        $Reader.ReadToEnd() | Write-Host
        
        Exit 1
    }
} (Get-Param 'ServiceIds' -Required) (Get-Param 'RequesterId' -Required) (Get-Param 'Description' -Required) (Get-Param 'Minutes' -Required) (Get-Param 'Token' -Required)