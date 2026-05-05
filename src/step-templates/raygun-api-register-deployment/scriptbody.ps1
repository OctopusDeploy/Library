Function Get-Parameter($Name, [switch]$Required, $Default, [switch]$FailOnValidate) {
    $result = $null
    $errMessage = [string]::Empty

    If ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
        Write-Host "Octopus paramter value for $Name : $result"
    }

    If ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    If ($result -eq $null) {
        If ($Required) {
            $errMessage = "Missing parameter value $Name"
        } Else {
            $result = $Default
        }
    } 

    If (-Not [string]::IsNullOrEmpty($errMessage)) {
        If ($FailOnValidate) {
            Throw $errMessage
        } Else {
            Write-Warning $errMessage
        }
    }

    return $result
}

& {
    Write-Host "Start AddInRaygun"

    $deploymentId = [string] (Get-Parameter "Octopus.Release.Number" $true [string]::Empty $true)
    $ownerName = [string] (Get-Parameter "Octopus.Deployment.CreatedBy.DisplayName" $true [string]::Empty $true)
    $emailAddress = [string] (Get-Parameter "Octopus.Deployment.CreatedBy.EmailAddress" $false [string]::Empty $true)
    $releaseNotes = [string] (Get-Parameter "Octopus.Release.Notes" $false [string]::Empty $true)
    $personAccessToken = [string] (Get-Parameter "Raygun.PersonalAccessToken" $true [string]::Empty $true)
    $apiKey = [string] (Get-Parameter "Raygun.ApiKey" $true [string]::Empty $true)
    $deployedAt = Get-Date -Format "o"

    Write-Host "Registering deployment with Raygun"

    # Some older API keys may contain URL reserved characters (eg '/', '=', '+') and will need to be encoded.
    # If your API key does not contain any reserved characters you can exclude the following line.
    $urlEncodedApiKey = [System.Uri]::EscapeDataString($apiKey);

    $url = "https://api.raygun.com/v3/applications/api-key/" + $urlEncodedApiKey + "/deployments"

    $headers = @{
        Authorization="Bearer " + $personAccessToken
    }

    $payload = @{
        version = $deploymentId
        ownerName = $ownerName
        emailAddress = $emailAddress
        comment = $releaseNotes
        deployedAt = $deployedAt
    }

    $payloadJson = $payload | ConvertTo-Json 


    try {
        Invoke-RestMethod -Uri $url -Body $payloadJson -Method Post -Headers $headers -ContentType "application/json" -AllowInsecureRedirect
        Write-Host "Deployment registered with Raygun"
    } catch {
        Write-Host "Tried to send a deployment to " $url " with payload " $payloadJson
        Write-Error "Error received when registering deployment with Raygun: $_"
    }

    Write-Host "End AddInRaygun"
}