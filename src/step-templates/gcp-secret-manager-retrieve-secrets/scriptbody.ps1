$ErrorActionPreference = 'Stop'

# Variables
$SecretNames = $OctopusParameters["GCP.SecretManager.RetrieveSecrets.SecretNames"]
$PrintVariableNames = $OctopusParameters["GCP.SecretManager.RetrieveSecrets.PrintVariableNames"]

# GCP Project/Region/Zone
$Project = $OctopusParameters["GCP.SecretManager.RetrieveSecrets.Project"]
$Region = $OctopusParameters["GCP.SecretManager.RetrieveSecrets.Region"]
$Zone = $OctopusParameters["GCP.SecretManager.RetrieveSecrets.Zone"]

# Validation
if ([string]::IsNullOrWhiteSpace($SecretNames)) {
    throw "Required parameter GCP.SecretManager.RetrieveSecrets.SecretNames not specified"
}

$Secrets = @()
$VariablesCreated = 0
$StepName = $OctopusParameters["Octopus.Step.Name"]

# Extract secret names
@(($SecretNames -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"
        $secretDefinition = ($_ -Split "\|")
        $secretName = $secretDefinition[0].Trim()
        $secretNameAndVersion = ($secretName -Split " ")
        $secretVersion = "latest"
        if ($secretNameAndVersion.Count -gt 1) {
            $secretName = $secretNameAndVersion[0].Trim()
            $secretVersion = $secretNameAndVersion[1].Trim()
        }
        if ([string]::IsNullOrWhiteSpace($secretName)) {
            throw "Unable to establish secret name from: '$($_)'"
        }
        $secret = [PsCustomObject]@{
            Name          = $secretName
            SecretVersion = $secretVersion
            VariableName  = if (![string]::IsNullOrWhiteSpace($secretDefinition[1])) { $secretDefinition[1].Trim() } else { "" }
        }
        $Secrets += $secret
    }
}

Write-Verbose "GCP Default Project: $Project"
Write-Verbose "GCP Default Region: $Region"
Write-Verbose "GCP Default Zone: $Zone"
Write-Verbose "Secrets to retrieve: $($Secrets.Count)"
Write-Verbose "Print variables: $PrintVariableNames"

# Retrieve Secrets
foreach ($secret in $secrets) {
    $name = $secret.Name
    $secretVersion = $secret.SecretVersion
    $variableName = $secret.VariableName
    if ([string]::IsNullOrWhiteSpace($variableName)) {
        $variableName = "$($name.Trim())-$secretVersion"
    }
    Write-Host "Retrieving Secret '$name' (version: $secretVersion)"
    if ($secretVersion -ieq "latest") {
        Write-Host "Note: Retrieving the 'latest' version for secret '$name' isn't recommended. Consider choosing a specific version to retrieve."
    }
    
    $secretValue = (gcloud secrets versions access $secretVersion --secret="$name") -Join "`n"
    
    if ([string]::IsNullOrWhiteSpace($secretValue)) {
        throw "Error: Secret '$name' (version: $secretVersion) not found or has no versions."
    }

    Set-OctopusVariable -Name $variableName -Value $secretValue -Sensitive

    if ($PrintVariableNames -eq $True) {
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
    }
    $VariablesCreated += 1
}

Write-Host "Created $variablesCreated output variables"
