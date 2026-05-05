$ErrorActionPreference = 'Stop'

# Variables
$global:AzureAppConfigStoreName = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.ConfigStoreName"]
$global:AzureAppConfigStoreEndpoint = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.ConfigStoreEndpoint"]
$global:AzureAppConfigRetrievalMethod = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.RetrievalMethod"]
$ConfigStoreKeyNames = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.KeyNames"]
$global:ConfigStoreLabels = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.Labels"]
$PrintVariableNames = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.PrintVariableNames"]
$SaveValuesAsSensitiveVariables = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.SaveAsSensitiveVariables"] -ieq "True"
$global:SuppressWarnings = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.SuppressWarnings"] -ieq "True"
$global:TreatWarningsAsErrors = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.TreatWarningsAsErrors"] -ieq "True"
$global:CreateAppSettingsJson = $OctopusParameters["Azure.AppConfig.KV.RetrieveValues.CreateAppSettingsJson"] -ieq "True"

# Validation
if ([string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreName) -and [string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreEndpoint)) {
    throw "Either parameter ConfigStoreName or ConfigStoreEndpoint not specified"
}

if ([string]::IsNullOrWhiteSpace($global:AzureAppConfigRetrievalMethod)) {
    throw "Required parameter Azure.AppConfig.KV.RetrieveValues.RetrievalMethod not specified"
}

if ([string]::IsNullOrWhiteSpace($ConfigStoreKeyNames) -and [string]::IsNullOrWhiteSpace($global:ConfigStoreLabels)) {
    throw "Either Azure.AppConfig.KV.RetrieveValues.KeyNames or Azure.AppConfig.KV.RetrieveValues.Labels not specified"
}

$RetrieveAllKeys = $global:AzureAppConfigRetrievalMethod -ieq "all"
$global:ConfigStoreParameters = ""
if (-not [string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreName)) {
    $global:ConfigStoreParameters += " --name ""$global:AzureAppConfigStoreName"""
}
if (-not [string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreEndpoint)) {
    $global:ConfigStoreParameters += " --endpoint ""$global:AzureAppConfigStoreEndpoint"""
}

### Helper functions
function Test-ForAzCLI() {
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    try { 
        if (Get-Command "az") {
            return $True
        }
    }
    catch { 
        return $false
    }
    finally { 
        $ErrorActionPreference = $oldPreference 
    }
}

function Write-OctopusWarning(
    [string] $Message
) {
    if ($global:TreatWarningsAsErrors) {
        throw "Error: $($Message)"
    }
    else {
        if ($global:SuppressWarnings -eq $False) {
            Write-Warning -Message $Message
        }
        else {
            Write-Verbose -Message $Message
        }
    }
}


function Save-OctopusVariable(
    [string]$variableName, 
    [string]$variableValue) {

    $VariableParams = @{name = $variableName; Value = $variableValue } 
                    
    if ($SaveValuesAsSensitiveVariables) {
        $VariableParams.Sensitive = $True
    }

    Set-OctopusVariable @VariableParams

    $global:VariablesCreated += 1

    if ($global:CreateAppSettingsJson) {
        $global:AppSettingsVariables += [PsCustomObject]@{name = $variableName; value = $variableValue; slotSetting = $false }
    }

    if ($PrintVariableNames) {
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
    }
}

function Find-AzureAppConfigMatchesFromKey(
    [string]$KeyName,
    [bool]$IsWildCard,
    [string]$VariableName,
    [PsCustomObject]$AppConfigValues) {

    if ($IsWildCard -eq $False) {
        Write-Verbose "Finding exact match for: $($keyName)"
        $matchingAppConfigKeys = $appConfigValues | Where-Object { $_.key -ieq $keyName }
        if ($null -eq $matchingAppConfigKeys -or $matchingAppConfigKeys.Count -eq 0) {
            Write-OctopusWarning "Unable to find a matching key in Azure App Config for: $($keyName)"
        }
        else {
            if ($matchingAppConfigKeys.Count -gt 1) {
                Write-OctopusWarning "Found multiple matching keys ($($matchingAppConfigKeys.Count)) in Azure App Config for: $($keyName). This is usually due to multiple values with labels"

                foreach ($matchingAppConfigKey in $matchingAppConfigKeys) {
                    Write-Verbose "Found match for $($keyName) $(if(![string]::IsNullOrWhiteSpace($matchingAppConfigKey.label)) {"(label: $($matchingAppConfigKey.label))"})"
                    $variableValue = $matchingAppConfigKey.value
                    
                    if ([string]::IsNullOrWhiteSpace($variableName)) {
                        $variableName = $keyName.Trim()
                    }
                    
                    if (![string]::IsNullOrWhiteSpace($matchingAppConfigKey.label)) {
                        $variableName = "$($keyName.Trim())-$($matchingAppConfigKey.label)"
                        Write-Verbose "Appending label to variable name to avoid duplicate output name: $variableName"
                    }

                    Save-OctopusVariable -variableName $variableName -variableValue $variableValue
                }
            } 
            else {
                $matchingAppConfigKey = $matchingAppConfigKeys | Select-Object -First 1

                Write-Verbose "Found match for $($keyName)"
                $variableValue = $matchingAppConfigKey.value
    
                if ([string]::IsNullOrWhiteSpace($variableName)) {
                    $variableName = "$($keyName.Trim())"
                }
    
                Save-OctopusVariable -variableName $variableName -variableValue $variableValue
            }
        }
    }
    else {
        Write-Verbose "Finding wildcard match for: $($keyName)"
        $matchingAppConfigKeys = @($appConfigValues | Where-Object { $_.key -ilike $keyName })
        if ($matchingAppConfigKeys.Count -eq 0) {
            Write-OctopusWarning "Unable to find any matching keys in Azure App Config for wildcard: $($keyName)"
        }
        else {
            foreach ($match in $matchingAppConfigKeys) {
                # Have to explicitly set variable Name here as its a wildcard match
                $variableName = $match.key
                $variableValue = $match.value
                Write-Verbose "Found wildcard match '$variableName' $(if(![string]::IsNullOrWhiteSpace($matchingAppConfigKey.content_type)) {"($($matchingAppConfigKey.content_type))"})"
                Save-OctopusVariable -variableName $variableName -variableValue $variableValue
            }
        }
    }
}

function Find-AzureAppConfigMatchesFromLabels() {
    
    Write-Verbose "Retrieving values matching labels: $($global:ConfigStoreLabels)"
    $command = "az appconfig kv list $($global:ConfigStoreParameters) --label ""$global:ConfigStoreLabels"" --auth-mode login"
            
    Write-Verbose "Invoking expression: $command"
    $appConfigResponse = Invoke-Expression -Command $command
    $ExitCode = $LastExitCode
    Write-Verbose "az exit code: $ExitCode"
    if ($ExitCode -ne 0) {
        throw "Error retrieving appsettings. ExitCode: $ExitCode"
    }

    if ([string]::IsNullOrWhiteSpace($appConfigResponse)) {
        Write-OctopusWarning "Null or empty response received from Azure App Configuration service"
    }
    else {
        $appConfigValues = $appConfigResponse | ConvertFrom-Json
        if ($appConfigValues.Count -eq 0) {
            Write-OctopusWarning "Unable to find any matching keys in Azure App Config for labels: $($global:ConfigStoreLabels)"
        }
        else {
            Write-Verbose "Finding match(es) for labels: $($global:ConfigStoreLabels)"
            foreach ($appConfigValue in $appConfigValues) {
                # Have to explicitly set variable Name here as its a match based on label alone
                $variableName = $appConfigValue.key
                Write-Verbose "Found label match '$($appConfigValue.key)' $(if(![string]::IsNullOrWhiteSpace($appConfigValue.content_type)) {"($($appConfigValue.content_type))"})"
                if (![string]::IsNullOrWhiteSpace($appConfigValue.label)) {
                    $variableName = "$($variableName)-$($appConfigValue.label)"
                    Write-Verbose "Appending label to variable name to avoid duplicate output name: $variableName"
                }
                $variableValue = $appConfigValue.value
                
                Save-OctopusVariable -variableName $variableName -variableValue $variableValue
            }
        }
    }
}

# Check if Az cli is installed.
$azCliAvailable = Test-ForAzCLI
if ($azCliAvailable -eq $False) {
    throw "Cannot find the Azure CLI (az) on the machine. This must be available to continue."	
}

$Keys = @()
$global:VariablesCreated = 0
$global:AppSettingsVariables = @()
$StepName = $OctopusParameters["Octopus.Step.Name"]

# Extract key names+optional custom variable name
@(($ConfigStoreKeyNames -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"
        $keyDefinition = ($_ -Split "\|")
        $keyName = $keyDefinition[0].Trim()
        $KeyIsWildcard = $keyName.EndsWith("*")
        $variableName = $null
        if ($keyDefinition.Count -gt 1) {
            if ($KeyIsWildcard) {
                throw "Key definition: '$_' evaluated as a wildcard with a custom variable name. This is not supported."
            }
            $variableName = $keyDefinition[1].Trim()
        }

        if ([string]::IsNullOrWhiteSpace($keyName)) {
            throw "Unable to establish key name from: '$($_)'"
        }

        $key = [PsCustomObject]@{
            KeyName       = $keyName
            KeyIsWildcard = $KeyIsWildcard
            VariableName  = if (![string]::IsNullOrWhiteSpace($variableName)) { $variableName } else { "" }
        }
        $Keys += $key
    }
}

$LabelsArray = $global:ConfigStoreLabels -Split "," | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $False }

Write-Verbose "Azure AppConfig Retrieval Method: $global:AzureAppConfigRetrievalMethod"
if (![string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreName)) {
    Write-Verbose "Azure AppConfig Store Name: $global:AzureAppConfigStoreName"
}
if (![string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreEndpoint)) {
    Write-Verbose "Azure AppConfig Store Endpoint: $global:AzureAppConfigStoreEndpoint"
}
Write-Verbose "Save sensitive variables: $SaveValuesAsSensitiveVariables"
Write-Verbose "Treat warnings as errors: $global:TreatWarningsAsErrors"
Write-Verbose "Suppress warnings: $global:SuppressWarnings"
Write-Verbose "Print variables: $PrintVariableNames"
Write-Verbose "Keys to retrieve: $($Keys.Count)"
Write-Verbose "Labels to retrieve: $($LabelsArray.Count)"

$appConfigResponse = $null

# Retrieving all keys should be more performant, but may have a larger payload response.
if ($RetrieveAllKeys) {
    
    if ($Keys.Count -gt 0) {
        Write-Host "Retrieving ALL config values from store"
        $command = "az appconfig kv list $($global:ConfigStoreParameters) --all --auth-mode login"
    
        if (![string]::IsNullOrWhiteSpace($global:ConfigStoreLabels)) {
            $command += " --label ""$($global:ConfigStoreLabels)"" "
        }
        Write-Verbose "Invoking expression: $command"
        $appConfigResponse = Invoke-Expression -Command $command
        $ExitCode = $LastExitCode
        Write-Verbose "az exit code: $ExitCode"
        if ($ExitCode -ne 0) {
            throw "Error retrieving appsettings. ExitCode: $ExitCode"
        }
    
        if ([string]::IsNullOrWhiteSpace($appConfigResponse)) {
            Write-OctopusWarning "Null or empty response received from Azure App Configuration service"
        }
        else {
            $appConfigValues = $appConfigResponse | ConvertFrom-Json
        }

        foreach ($key in $Keys) {
            $keyName = $key.KeyName
            $KeyIsWildcard = $key.KeyIsWildcard
            $variableName = $key.VariableName
        
            Find-AzureAppConfigMatchesFromKey -KeyName $keyName -IsWildcard $KeyIsWildcard -VariableName $variableName -AppConfigValues $appConfigValues
        }
    }
    # Possible that ONLY labels have been provided
    elseif ($LabelsArray.Count -gt 0) {
        Find-AzureAppConfigMatchesFromLabels 
    }
}
# Loop through and get keys based on the supplied names
else {
    
    Write-Host "Retrieving keys based on supplied names..."
    if ($Keys.Count -gt 0) {
        foreach ($key in $Keys) {
            $keyName = $key.KeyName
            $KeyIsWildcard = $key.KeyIsWildcard
            $variableName = $key.VariableName

            if ([string]::IsNullOrWhiteSpace($variableName)) {
                $variableName = "$($keyName.Trim())"
            }

            Write-Verbose "Retrieving values matching key: $($keyName) from store"
            $command = "az appconfig kv list $($global:ConfigStoreParameters) --key ""$keyName"" --auth-mode login"
            
            if (![string]::IsNullOrWhiteSpace($global:ConfigStoreLabels)) {
                $command += " --label ""$($global:ConfigStoreLabels)"" "
            }
            Write-Verbose "Invoking expression: $command"

            $appConfigResponse = Invoke-Expression -Command $command
            $ExitCode = $LastExitCode
            Write-Verbose "az exit code: $ExitCode"
            if ($ExitCode -ne 0) {
                throw "Error retrieving appsettings. ExitCode: $ExitCode"
            }

            if ([string]::IsNullOrWhiteSpace($appConfigResponse)) {
                Write-OctopusWarning "Null or empty response received from Azure App Configuration service"
            }
            else {
                $appConfigValues = $appConfigResponse | ConvertFrom-Json
                if ($appConfigValues.Count -eq 0) {
                    Write-OctopusWarning "Unable to find a matching key in Azure App Config for: $($keyName)"
                }
                else {
                    Write-Verbose "Finding match(es) for: $($keyName)"
                    Find-AzureAppConfigMatchesFromKey -KeyName $keyName -IsWildcard $KeyIsWildcard -VariableName $variableName -AppConfigValues $appConfigValues
                }
            }
        }
    }
}

if ($global:AppSettingsVariables.Count -gt 0 -and $global:CreateAppSettingsJson) {
    Write-Verbose "Creating AppSettings JSON output variable"
    $AppSettingsJson = ($global:AppSettingsVariables | Sort-Object -Property * -Unique) | ConvertTo-Json -Compress -Depth 10
    if ($SaveValuesAsSensitiveVariables) {
        Set-OctopusVariable -Name "AppSettingsJson" -Value $AppSettingsJson -Sensitive
    }
    else {
        Set-OctopusVariable -Name "AppSettingsJson" -Value $AppSettingsJson 
    }
    $global:VariablesCreated += 1
    if ($PrintVariableNames) {
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.AppSettingsJson}"
    }
}

Write-Host "Created $global:VariablesCreated output variable(s)"