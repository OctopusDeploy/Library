$ErrorActionPreference = 'Stop'

# Variables
$BwsServerUrl = $OctopusParameters["Bitwarden.SecretsManager.RetrieveSecrets.ServerUrl"]
$ProjectName = $OctopusParameters["Bitwarden.SecretsManager.RetrieveSecrets.ProjectName"]
$BwsAccessToken = $OctopusParameters["Bitwarden.SecretsManager.RetrieveSecrets.AccessToken"]
$SecretNames = $OctopusParameters["Bitwarden.SecretsManager.RetrieveSecrets.SecretNames"]
$PrintVariableNames = $OctopusParameters["Bitwarden.SecretsManager.RetrieveSecrets.PrintVariableNames"]

Write-Output "Verifying 'bws' command availability..."
if (-not (Get-Command bws -ErrorAction SilentlyContinue)) {
    throw "The 'bws' (Bitwarden Secrets Manager CLI) command was not found. Please ensure it is installed and available in the system's PATH."
}
Write-Output "'bws' command found."

# Validation
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    throw "Required parameter Bitwarden.SecretsManager.RetrieveSecrets.ProjectName not specified."
}
if ([string]::IsNullOrWhiteSpace($BwsServerUrl)) {
    throw "Required parameter Bitwarden.SecretsManager.RetrieveSecrets.ServerURL not specified."
}
if ([string]::IsNullOrWhiteSpace($BwsAccessToken)) {
    throw "Required parameter Bitwarden.SecretsManager.RetrieveSecrets.AccessToken not specified."
}
if ([string]::IsNullOrWhiteSpace($SecretNames)) {
    throw "Required parameter Bitwarden.SecretsManager.RetrieveSecrets.SecretNames not specified."
}

# Functions
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
        Write-Output "Created output variable: ##{Octopus.Action[$StepName].Output.$name}"
    }
}

function Get-BwsProjectIdByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    # 1. API Call: Retrieve all projects in JSON format (1st API Call)
    $ProjectJson = bws project list `
        --access-token $AccessToken `
        --server-url $BwsServerUrl `
        --output json | Out-String

    # 2. Convert to PowerShell objects and filter by name
    $Projects = $ProjectJson | ConvertFrom-Json

    # 3. Find the ID of the matching project
    $ProjectObject = $Projects | Where-Object { $_.name -eq $Name }

    if (-not $ProjectObject) {
        throw "Error: Project '$Name' not found."
    }

    # Handle the case where the project name might not be unique
    if ($ProjectObject.Count -gt 1) {
        Write-Warning "Multiple projects found with name '$Name'. Using the first ID found."
    }

    # Return the ID
    return $ProjectObject.id
}

# End Functions

$script:storedVariables = @()
$StepName = $OctopusParameters["Octopus.Step.Name"]
$Secrets = @()

# Extract secret names
@(($SecretNames -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"
        $secretDefinition = ($_ -Split "\|")
        $secretName = $secretDefinition[0].Trim()
        
        if ([string]::IsNullOrWhiteSpace($secretName)) {
            throw "Unable to establish secret name from: '$($_)'"
        }
        $secret = [PsCustomObject]@{
            Name         = $secretName
            VariableName = if ($secretDefinition.Count -gt 1 -and ![string]::IsNullOrWhiteSpace($secretDefinition[1])) { $secretDefinition[1].Trim() } else { $secretName } # If VariableName is blank, use SecretName
        }
        $Secrets += $secret
    }
}

Write-Verbose "Project Name: $ProjectName"
Write-Verbose "Secrets to retrieve: $($Secrets.Count)"
Write-Verbose "Print variables: $PrintVariableNames"

try {

    # 1. Get the Project ID from the friendly name
    Write-Output "Looking up project ID for '$ProjectName'"
    $ProjectID = Get-BwsProjectIdByName -Name $ProjectName -AccessToken $BwsAccessToken
    
    Write-Output "Project ID found: $ProjectID"
    
    # 2. Retrieve all secrets from the found project (The single efficient call)
    Write-Output "Fetching all secrets from project."
    $SecretNamesToQuery = @($Secrets | Select-Object -ExpandProperty Name)

    # Use the projectId to get all secrets in that project
    $SecretsJson = bws secret list $ProjectID `
        --access-token $BwsAccessToken `
        --server-url $BwsServerUrl `
        --output json | Out-String
    $AllSecrets = $SecretsJson | ConvertFrom-Json

    # 3. Filter the local objects to only include the desired secret names
    Write-Output "Filtering for desired secrets: $($SecretNamesToQuery -join ', ')."
    $FilteredSecrets = $AllSecrets | Where-Object { $_.key -in $SecretNamesToQuery } | Select-Object -Property key, value
    
    foreach ($secret in $FilteredSecrets) {
        # Find the VariableName associated with the secret key
        $variableName = ($Secrets | Where-Object { $_.Name -eq $secret.key }).VariableName    
        
        # Save the secret value to the output variable
        Save-OctopusVariable -name $variableName -value $secret.value
    }
}
catch {
    throw "An error occurred while retrieving secrets: $($_.Exception.Message)"
}

Write-Output "Created $($script:storedVariables.Count) output variables"