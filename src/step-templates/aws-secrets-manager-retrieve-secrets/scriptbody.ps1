$ErrorActionPreference = 'Stop'

# Variables
$SecretNames = $OctopusParameters["AWS.SecretsManager.RetrieveSecrets.SecretNames"]
$PrintVariableNames = $OctopusParameters["AWS.SecretsManager.RetrieveSecrets.PrintVariableNames"]

# Validation
if ([string]::IsNullOrWhiteSpace($SecretNames)) {
    throw "Required parameter AWS.SecretsManager.RetrieveSecrets.SecretNames not specified"
}

# Functions
function Format-SecretName {
    [CmdletBinding()]
    Param(
        [string] $Name,
        [string] $VersionId,
        [string] $VersionStage,
        [string[]] $Keys
    )
    $displayName = "'$Name'"
    if (![string]::IsNullOrWhiteSpace($VersionId)) {
        $displayName += " $VersionId"
    }
    if (![string]::IsNullOrWhiteSpace($VersionStage)) {
        $displayName += " $VersionStage"
    }
    if ($Keys.Count -gt 0) {
        $displayName += " ($($Keys -Join ","))"
    }
    return $displayName
}

function Save-OctopusVariable {
    Param(
        [string] $name,
        [string] $value
    )
    if ($script:storedVariables -icontains $name) {
        Write-Warning "A variable with name '$name' has already been created. Check your secret name parameters as this will likely cause unexpected behavior and should be investigated."
    }
    Set-OctopusVariable -Name $name -Value $value -Sensitive
    $script:storedVariables += $name

    if ($PrintVariableNames -eq $True) {
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$name}"
    }
}

# End Functions

$script:storedVariables = @()
$StepName = $OctopusParameters["Octopus.Step.Name"]
$Secrets = @()

# Extract secret names
@(($SecretNames -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working establishing secret definition for: '$_'"
        $secretDefinition = ($_ -Split "\|")
        
        # Establish the secret name/version requirements
        $secretName = $secretDefinition[0].Trim()
        $secretVersionId = ""
        $secretVersionStage = ""
        $secretNameAndVersion = ($secretName -Split " ")
        
        if ($secretNameAndVersion.Count -gt 1) {
            $secretName = $secretNameAndVersion[0].Trim()
            $secretVersionId = $secretNameAndVersion[1].Trim()
            if ($secretNameAndVersion.Count -eq 3) {
                $secretVersionStage = $secretNameAndVersion[2].Trim()
            }
        }
    
        if ([string]::IsNullOrWhiteSpace($secretName)) {
            throw "Unable to establish secret name from: '$($_)'"
        }

        # Establish the secret field(s)/output variable name requirements.
        $VariableName = ""
        $Keys = @()
        if ($secretDefinition.Count -gt 1) {
            $KeyNames = $secretDefinition[1].Trim()        
            $Keys = @(($KeyNames -Split " "))
            $EmptyKeys = $Keys | Where-Object { [string]::IsNullOrWhiteSpace($_) }
            if ($Keys.Count -le 0 -or $EmptyKeys.Count -gt 0) {
                throw "No keys (field names) were specified for '$_'. To retrieve all keys in a secret, add the word ALL or the wildcard (*) character."    
            }
            
            if ($secretDefinition.Count -gt 2) {
                $VariableName = $secretDefinition[2].Trim()
            }
        }
        else {
            throw "No keys (field names) were specified for '$_'. To retrieve all keys in a secret, add the word ALL or the wildcard (*) character."
        }

        $secret = [PsCustomObject]@{
            Name                 = $secretName
            SecretVersionId      = $secretVersionId
            SecretVersionStage   = $secretVersionStage
            Keys                 = $Keys
            variableNameOrPrefix = $VariableName
        }
        $Secrets += $secret
    }
}

Write-Verbose "Secrets to retrieve: $($Secrets.Count)"
Write-Verbose "Print variables: $PrintVariableNames"

$retrievedSecrets = @{}

# Retrieve Secrets
foreach ($secret in $secrets) {
    $name = $secret.Name
    $versionId = $secret.SecretVersionId
    $versionStage = $secret.SecretVersionStage
    $variableNameOrPrefix = $secret.variableNameOrPrefix
    $keys = $secret.Keys
    
    # Should we extract only specified keys, or all values?
    $SpecifiedKeys = $True
    if ($keys.Count -eq 1 -and ($keys[0] -ieq "all" -or $keys[0] -ieq "*")) {
        $SpecifiedKeys = $False
    }
    
    $displayName = Format-SecretName -Name $name -VersionId $versionId -VersionStage $versionStage -Keys $keys
    Write-Verbose "Retrieving Secret $displayName"
    $_secretIdentifier = "$name"

    $params = @("--secret-id $name")
    if (![string]::IsNullOrWhiteSpace($versionId)) {
        $params += "--version-id $versionId"
        $_secretIdentifier += "_$versionId"
    }
    if (![string]::IsNullOrWhiteSpace($versionStage)) {
        $params += "--version-stage $versionStage"
        $_secretIdentifier += "_$versionStage"
    }
    
    # Check to see if we've already retrieved this secret value to save on requests
    if (-not $retrievedSecrets.ContainsKey($_secretIdentifier)) {
        $command = "aws secretsmanager get-secret-value $($params -Join " ")"
        Write-Verbose "Invoking command: $command"
        $response = Invoke-Expression -Command $command
        if ([string]::IsNullOrWhiteSpace($response)) {
            throw "Error: Secret $displayName not found or has no versions."
        }
        Write-Verbose "Added secret to retrieved collection ($_secretIdentifier)"
        $retrievedSecrets.Add($_secretIdentifier, $response)
    }
    else {
        Write-Verbose "Rehydrating previously stored secret ($_secretIdentifier) instead of calling AWS."
        $response = $retrievedSecrets.$_secretIdentifier
    }    
    
    try {
        $AwsSecret = $response | ConvertFrom-Json
        $AwsSecretValue = $AwsSecret.SecretString | ConvertFrom-Json
        $secretKeyValues = $AwsSecretValue | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty "Name"
    }
    catch {
        Write-Error "Error converting JSON value returned from AWS for $displayName.`n`nIf secret value is stored as JSON in Plaintext (vs Key/value), check contents validity"
    }
    if ($SpecifiedKeys -eq $True) {
        foreach ($keyName in $keys) {
            $variableName = $variableNameOrPrefix
            if ([string]::IsNullOrWhiteSpace($variableName)) {
                $variableName = "$($name.Trim())"
            }
            if ($keys.Count -gt 1) {
                $variableName += ".$keyName"
            }
            if ($secretKeyValues -inotcontains $keyName) {
                throw "Key '$keyName' not found in AWS Secret: $name."
            }
            $variableValue = $AwsSecretValue.$keyName
            Save-OctopusVariable -Name $variableName -Value $variableValue            
        }
    }
    else {
        foreach ($secretKeyValueName in $secretKeyValues) {
            $variableName = $variableNameOrPrefix
            if ([string]::IsNullOrWhiteSpace($variableName)) {
                $variableName = "$($name.Trim())"
            }
            if ($secretKeyValues.Count -gt 1) {
                $variableName += ".$secretKeyValueName"
            }
            $variableValue = $AwsSecretValue.$secretKeyValueName
            Save-OctopusVariable -Name $variableName -Value $variableValue
        }
    }
}

Write-Host "Created $($script:storedVariables.Count) output variables"