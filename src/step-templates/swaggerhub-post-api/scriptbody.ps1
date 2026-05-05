function Coalesce($a, $b) { 
    if ($null -ne $a) { 
        $a 
    } else { 
        $b 
    } 
}

function Validate([string]$parameterValue, [string[]]$validInput, $parameterName) {
    Write-Host "${parameterName}: $parameterValue"

    if (!$parameterValue) {
        throw "Parameter $parameterName is required!"
    }
    
    if ($validInput) {
        if (! $validInput -contains $parameterValue) {
            throw "'$input' is not a valid value for '$parameterName'"
        }
    }
}

$apiKey = $OctopusParameters['shpApiKey']
$owner = $OctopusParameters['shpOwner']
$apiName = $OctopusParameters['shpApi']
$definition = $OctopusParameters['shpDefinition']
$contentType = Coalesce $OctopusParameters['shpContentType'] "application/json"
$oas = Coalesce $OctopusParameters['shpOas'] "2.0"
$isPrivate = (Coalesce $OctopusParameters['shpIsPrivate'] "False").ToLower()
$force = (Coalesce $OctopusParameters['shpForce'] "False").ToLower()
$version = $OctopusParameters['shpVersion']

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

Validate $apiKey -parameterName "Api Key"
Validate $owner -parameterName "Owner"
Validate $apiName -parameterName "Api Name"
Validate $definition -parameterName "Definition"

try {
    Write-Host "Updating $($apiName)..."

    $headers = @{ 
        'Authorization' = $apiKey 
        'Accept' = 'application/json'
    }    
    
    $query = "https://api.swaggerhub.com/apis/$($owner)/$($apiName)?isPrivate=$($isPrivate.ToLower())&oas=$($oas)&force=$($force.ToLower())"

    if($version) {
        $query = $query+"&version=$($version)"
    }
    
    $specification = $definition
    
    # If $definition contains a file path, load the content of the provided value
    if((Test-Path $definition -ErrorAction SilentlyContinue)[0]) {
        $specification = get-content $definition
    }

    Invoke-RestMethod $query -Headers $headers -ContentType $contentType -Method Post -Body $specification

    Write-Host "SwaggerHub post successful"
} catch {
    Write-Host $_.Exception.Message
    Write-Host "SwaggerHub post failed!"
    Write-Host "  HttpStatus: $($_.Exception.Response.StatusCode.value__)" 

    exit 1
}
