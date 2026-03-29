# Running outside octopus
param(
    [string]$odEnv,
    [string]$odName,
    [string]$odRole,
    [int]$odTimeout,
    [string]$odUrl,
    [string]$odApiKey,
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

    if (!$result -or $result -eq $null) {
        if ($Default) {
            $result = $Default
        } elseif ($Required) {
            throw "Missing parameter value $Name"
        }
    }

    return $result
}

& {
    param(
        [string]$odEnv,
        [string]$odName,
        [string]$odRole,
        [int]$odTimeout,
        [string]$odUrl,
        [string]$odApiKey
    )

    # If Octopus Deploy's URL/API Key are not provided as params, attempt to retrieve them from Environment Variables
    if (!$odUrl) {
        if ([Environment]::GetEnvironmentVariable("OD_API_URL", "Machine")) {
            $odUrl = [Environment]::GetEnvironmentVariable("OD_API_URL", "Machine")
        }
    }
    
    if (!$odUrl) { throw "Octopus Deploy API URL was not available/provided." }

    if (!$odApiKey) {
        if ([Environment]::GetEnvironmentVariable("OD_API_KEY", "Machine")) {
            $odApiKey = [Environment]::GetEnvironmentVariable("OD_API_KEY", "Machine")
        }
    } 
    
    if (!$odApiKey) { throw "Octopus Deploy API key was not available/provided." }

    $header = @{ "X-Octopus-ApiKey" = $odApiKey }
    
    Write-Verbose "Checking API compatibility";
    $rootDocument = Invoke-WebRequest "$odUrl/api/" -Header $header -UseBasicParsing | ConvertFrom-Json;
    if($rootDocument.Links -ne $null -and $rootDocument.Links.Spaces -ne $null) {
      Write-Verbose "Spaces API found"
      $hasSpacesApi = $true;
    } else {
      Write-Verbose "Pre-spaces API found"
      $hasSpacesApi = $false;
    }
    
    if($hasSpacesApi) {
        $spaceId = $OctopusParameters['Octopus.Space.Id'];
        if([string]::IsNullOrWhiteSpace($spaceId)) {
            throw "This step needs to be run in a context that provides a value for the 'Octopus.Space.Id' system variable. In this case, we received a blank value, which isn't expected - please reach out to our support team at https://help.octopus.com if you encounter this error.";
        }
        $baseApiUrl = "/api/$spaceId" ;
    } else {
        $baseApiUrl = "/api" ;
    }    
    
    $environments = (Invoke-WebRequest "$odUrl$baseApiUrl/environments/all" -Headers $header -UseBasicParsing).content | ConvertFrom-Json
    $environment = $environments | Where-Object { $_.Name -contains $odEnv }
    if (@($environment).Count -eq 0) { throw "Could not find environment with the name '$odEnv'" }
    
    $timeout = new-timespan -Seconds $odTimeout
    $sw = [diagnostics.stopwatch]::StartNew()

    Write-Output ("------------------------------")
    Write-Output ("Checking the Deployment Target's registration status:")
    Write-Output ("------------------------------")

    while ($true)
    {
        if ($sw.elapsed -gt $timeout) { throw "Timed out waiting for the Deployment Target to register" }
        
        $machines = ((Invoke-WebRequest ($odUrl + $environment.Links.Self + "/machines") -Headers $header -UseBasicParsing).content | ConvertFrom-Json).items
        if ($odName) { $machines = $machines | Where-Object { $_.Name -like "*$odName*" } }
        if ($odRole) { $machines = $machines | Where-Object { $_.Roles -like "*$odRole*" } }
        if (@($machines).Count -gt 0) { break }

        Write-Output ("$(Get-Date) | Waiting for Deployment Target to register with the name '$odName' and role '$odRole'")

        Start-Sleep -Seconds 5
    }
    
    Write-Output ("$(Get-Date) | Deployment Target registered with the name '$odName' and role '$odRole'!")
 } `
 (Get-Param 'odEnv' -Required) `
 (Get-Param 'odName' -Required) `
 (Get-Param 'odRole') `
 (Get-Param 'odTimeout' -Required) `
 (Get-Param 'odUrl') `
 (Get-Param 'odApiKey')