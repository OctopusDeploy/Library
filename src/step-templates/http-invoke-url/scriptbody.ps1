# Running outside octopus
param(
    [string]$url,
    [switch]$whatIf
) 

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
        [string]$url
    ) 

    Write-Host "Invoke Url: $url"

    try {
    
        Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing

    } catch {
        Write-Host "There was a problem invoking Url"    
    }

 } `
 (Get-Param 'url' -Required)