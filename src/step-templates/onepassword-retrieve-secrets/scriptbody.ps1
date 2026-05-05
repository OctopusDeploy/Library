# Check if the 1Password CLI is installed
if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-Output "Error: 1Password CLI (op) is not installed."
    exit 1
}

# Retrieve environment variables from Octopus
$env:OP_CONNECT_HOST =$OctopusParameters["OnePass.CONNECT_HOST"]
$env:OP_CONNECT_TOKEN = $OctopusParameters["OnePass.CONNECT_TOKEN"]

# Perform nslookup after removing "http://" or "https://"
$hostLookup = $env:OP_CONNECT_HOST -replace 'https?://', ''
nslookup $hostLookup

$STEP_NAME = $OctopusParameters["Octopus.Step.Name"]

# Retrieve the list of secrets to process from Octopus variable
$SECRETS = $OctopusParameters["OnePass.SecretsManager.RetrieveSecrets.SecretNames"]
Write-Output $SECRETS

# Validation
if ([string]::IsNullOrEmpty($SECRETS)) {
    Write-Output "Required parameter 'OnePass.SecretsManager.RetrieveSecrets.SecretNames' not specified. Exiting..."
    exit 1
}

# Helper function to save Octopus variable
function Save-OctopusVariable {
    param (
        [string]$name,
        [string]$value
    )

    Set-OctopusVariable -name $name -value $value --sensitive
    Write-Output "Created output variable: ##{Octopus.Action[$STEP_NAME].Output.$name}"
}

# Process each secret entry
$SECRETS -split "`n" | ForEach-Object {
    $secret_entry = $_.Trim()
    if ([string]::IsNullOrEmpty($secret_entry)) { return }

    # Check if the secret entry contains the '|' character
    if ($secret_entry -notmatch '\|') {
        Write-Output "Warning: The entry '$secret_entry' is not formatted correctly and will be skipped."
        return
    }

    # Parse the secret entry
    $split_entry = $secret_entry -split '\|'
    $secret_path = $split_entry[0].Trim()  # 1Password path
    $octopus_variable_name = $split_entry[1].Trim()  # Octopus variable name

    Write-Output "Fetching secret for path: $secret_path"

    # Retrieve the secret field using 1Password CLI
    $field_value = (& op read $secret_path 2>$null)

    # Validate retrieval
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($field_value)) {
        Write-Output "Error: Failed to retrieve secret for path '$secret_path'."
        exit 1
    }

    # Save the retrieved value in the specified Octopus variable
    Save-OctopusVariable -name $octopus_variable_name -value $field_value
    Write-Output "Secret retrieval and variable setting complete."
}