$ErrorActionPreference = 'Stop'

# KV Variables
$global:AzureAppConfigStoreName = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.ConfigStoreName"]
$global:AzureAppConfigStoreEndpoint = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.ConfigStoreEndpoint"]
$global:AzureAppConfigRetrievalMethod = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.RetrievalMethod"]
$ConfigStoreKeyNames = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.KeyNames"]
$global:ConfigStoreLabels = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.Labels"]
$global:SuppressWarnings = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.SuppressWarnings"] -ieq "True"
$global:TreatWarningsAsErrors = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.TreatWarningsAsErrors"] -ieq "True"

# Function Variables
$FunctionName = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.FunctionName"]
$ResourceGroup = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.ResourceGroup"]
$AdditionalSettingsValues = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.AdditionalSettingsValues"]
$Slot = $OctopusParameters["AzFunction.SetAppSettings.FromAzAppConfig.Slot"]

# KV params validation
if ([string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreName) -and [string]::IsNullOrWhiteSpace($global:AzureAppConfigStoreEndpoint)) {
    throw "Either parameter ConfigStoreName or ConfigStoreEndpoint not specified"
}

if ([string]::IsNullOrWhiteSpace($global:AzureAppConfigRetrievalMethod)) {
    throw "Required parameter AzFunction.SetAppSettings.FromAzAppConfig.RetrievalMethod not specified"
}

if ([string]::IsNullOrWhiteSpace($ConfigStoreKeyNames) -and [string]::IsNullOrWhiteSpace($global:ConfigStoreLabels)) {
    throw "Either AzFunction.SetAppSettings.FromAzAppConfig.KeyNames or AzFunction.SetAppSettings.FromAzAppConfig.Labels not specified"
}

# Function params validation
if ([string]::IsNullOrWhiteSpace($FunctionName)) {
    throw "Required parameter AzureFunction.ConfigureAppSettings.FunctionName not specified"
}

if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    throw "Required parameter AzureFunction.ConfigureAppSettings.ResourceGroup not specified"
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
        throw "Error: $Message"
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

function Save-AppSetting(
    [string]$settingName, 
    [string]$settingValue) {

    $global:Settings += [PsCustomObject]@{name = $settingName; value = $settingValue; slotSetting = $false }
}

function Find-AzureAppConfigMatchesFromKey(
    [string]$KeyName,
    [bool]$IsWildCard,
    [string]$settingName,
    [PsCustomObject]$AppConfigValues) {

    if ($IsWildCard -eq $False) {
        Write-Verbose "Finding exact match for: $keyName"
        $matchingAppConfigKeys = $appConfigValues | Where-Object { $_.key -ieq $keyName }
        if ($null -eq $matchingAppConfigKeys -or $matchingAppConfigKeys.Count -eq 0) {
            Write-OctopusWarning "Unable to find a matching key in Azure App Config for: $keyName"
        }
        else {

            if ($matchingAppConfigKeys.Count -gt 1) {
                Write-OctopusWarning "Found multiple matching keys ($($matchingAppConfigKeys.Count)) in Azure App Config for: $keyName. This is usually due to multiple values with labels"

                foreach ($matchingAppConfigKey in $matchingAppConfigKeys) {
                    Write-Verbose "Found match for $keyName $(if(![string]::IsNullOrWhiteSpace($matchingAppConfigKey.content_type)) {"($($matchingAppConfigKey.content_type))"})"
                    $settingValue = $matchingAppConfigKey.value
        
                    if ([string]::IsNullOrWhiteSpace($settingName)) {
                        $settingName = $keyName.Trim()
                    }
                    if (![string]::IsNullOrWhiteSpace($matchingAppConfigKey.label)) {
                        $settingName = "$($keyName.Trim())-$($matchingAppConfigKey.label)"
                        Write-Verbose "Appending label to setting name to avoid duplicate setting: $settingName"
                    }
        
                    Save-AppSetting -settingName $settingName -settingValue $settingValue
                }
            } 
            else {
                $matchingAppConfigKey = $matchingAppConfigKeys | Select-Object -First 1
                Write-Verbose "Found match for $keyName $(if(![string]::IsNullOrWhiteSpace($matchingAppConfigKey.content_type)) {"($($matchingAppConfigKey.content_type))"})"
                $settingValue = $matchingAppConfigKey.value
    
                if ([string]::IsNullOrWhiteSpace($settingName)) {
                    $settingName = $keyName.Trim()
                }
    
                Save-AppSetting -settingName $settingName -settingValue $settingValue
            }
        }
    }
    else {
        Write-Verbose "Finding wildcard match for: $keyName"
        $matchingAppConfigKeys = @($appConfigValues | Where-Object { $_.key -ilike $keyName })
        if ($matchingAppConfigKeys.Count -eq 0) {
            Write-OctopusWarning "Unable to find any matching keys in Azure App Config for wildcard: $keyName"
        }
        else {
            foreach ($match in $matchingAppConfigKeys) {
                # Have to explicitly set settings as they are wildcard matches
                $settingName = $match.key
                $settingValue = $match.value
                Write-Verbose "Found wildcard match '$settingName' $(if(![string]::IsNullOrWhiteSpace($matchingAppConfigKey.content_type)) {"($($matchingAppConfigKey.content_type))"})"
                Save-AppSetting -settingName $settingName -settingValue $settingValue
            }
        }
    }
}

function Find-AzureAppConfigMatchesFromLabels() {
    
    Write-Verbose "Retrieving values matching labels: $global:ConfigStoreLabels"
    $command = "az appconfig kv list $global:ConfigStoreParameters --label ""$global:ConfigStoreLabels"" --auth-mode login"
            
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
            Write-OctopusWarning "Unable to find any matching keys in Azure App Config for labels: $global:ConfigStoreLabels"
        }
        else {
            Write-Verbose "Finding match(es) for labels: $global:ConfigStoreLabels"
            foreach ($appConfigValue in $appConfigValues) {
                # Have to explicitly set setting Name here as its a match based on label alone
                $settingName = $appConfigValue.key
                Write-Verbose "Found label match '$($appConfigValue.key)' $(if(![string]::IsNullOrWhiteSpace($appConfigValue.content_type)) {"($($appConfigValue.content_type))"})"
                if (![string]::IsNullOrWhiteSpace($appConfigValue.label)) {
                    $settingName = "$($settingName)-$($appConfigValue.label)"
                    Write-Verbose "Appending label to setting to avoid duplicate name: $settingName"
                }
                $settingValue = $appConfigValue.value
                
                Save-AppSetting -settingName $settingName -settingValue $settingValue
            }
        }
    }
}

# Check if Az cli is installed.
$azCliAvailable = Test-ForAzCLI
if ($azCliAvailable -eq $False) {
    throw "Cannot find the Azure CLI (az) on the machine. This must be available to continue."	
}

# Begin KV Retrieval
$Keys = @()
$global:Settings = @()

# Extract key names+optional custom setting name
@(($ConfigStoreKeyNames -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"
        $keyDefinition = ($_ -Split "\|")
        $keyName = $keyDefinition[0].Trim()
        $KeyIsWildcard = $keyName.EndsWith("*")
        $settingName = $null
        if ($keyDefinition.Count -gt 1) {
            if ($KeyIsWildcard) {
                throw "Key definition: '$_' evaluated as a wildcard with a custom setting name. This is not supported."
            }
            $settingName = $keyDefinition[1].Trim()
        }

        if ([string]::IsNullOrWhiteSpace($keyName)) {
            throw "Unable to establish key name from: '$_'"
        }

        $key = [PsCustomObject]@{
            KeyName       = $keyName
            KeyIsWildcard = $KeyIsWildcard
            SettingName   = if (![string]::IsNullOrWhiteSpace($settingName)) { $settingName } else { "" }
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
Write-Verbose "Suppress warnings: $global:SuppressWarnings"
Write-Verbose "Treat warnings as errors: $global:TreatWarningsAsErrors"
Write-Verbose "Keys to retrieve: $($Keys.Count)"
Write-Verbose "Labels to retrieve: $($LabelsArray.Count)"

$appConfigResponse = $null

# Retrieving all keys should be more performant, but may have a larger payload response.
if ($RetrieveAllKeys) {
    
    if ($Keys.Count -gt 0) {
        Write-Host "Retrieving ALL config values from store"
        $command = "az appconfig kv list $global:ConfigStoreParameters --all --auth-mode login"
    
        if (![string]::IsNullOrWhiteSpace($global:ConfigStoreLabels)) {
            $command += " --label ""$global:ConfigStoreLabels"" "
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
            $SettingName = $key.SettingName
        
            Find-AzureAppConfigMatchesFromKey -KeyName $keyName -IsWildcard $KeyIsWildcard -SettingName $SettingName -AppConfigValues $appConfigValues
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
            $settingName = $key.SettingName

            if ([string]::IsNullOrWhiteSpace($settingName)) {
                $settingName = "$($keyName.Trim())"
            }

            Write-Verbose "Retrieving values matching key: $keyName from store"
            $command = "az appconfig kv list $global:ConfigStoreParameters --key ""$keyName"" --auth-mode login"
            
            if (![string]::IsNullOrWhiteSpace($global:ConfigStoreLabels)) {
                $command += " --label ""$global:ConfigStoreLabels"" "
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
                    Write-OctopusWarning "Unable to find a matching key in Azure App Config for: $keyName"
                }
                else {
                    Write-Verbose "Finding match(es) for: $keyName"
                    Find-AzureAppConfigMatchesFromKey -KeyName $keyName -IsWildcard $KeyIsWildcard -SettingName $settingName -AppConfigValues $appConfigValues
                }
            }
        }
    }
}
# End KV Retrieval

# Begin AZ Function set

$AdditionalSettings = @()
#$SlotSettings = @()

# Extract additional settings values
if (-not [string]::IsNullOrWhiteSpace($AdditionalSettingsValues)) {
    @(($AdditionalSettingsValues -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            Write-Verbose "Working on: '$_'"
            if (-not $_.Contains("|")) {
                throw "Setting '$_' doesnt contain the '|' delimiter. Multi-line values aren't supported."
            }
            $settingDefinition = ($_ -Split "\|")
            $settingName = $settingDefinition[0].Trim()
            $settingValue = ""
            if ($settingDefinition.Count -gt 1) {
                $settingValue = $settingDefinition[1].Trim()
            }
            if ([string]::IsNullOrWhiteSpace($settingName)) {
                throw "Unable to establish additional setting name from: '$_'"
            }
            $setting = [PsCustomObject]@{
                name        = $settingName
                value       = $settingValue
                slotSetting = $false
            }
            $AdditionalSettings += $setting
        }
    }
}


if ($Settings.Count -gt 0 -or $AdditionalSettings.Count -gt 0) {
    Write-Host "Settings found to publish to App Function: $FunctionName"

    Write-Verbose "Function Name: $FunctionName"
    Write-Verbose "Resource Group: $ResourceGroup"
    Write-Verbose "Slot: $Slot"
    Write-Verbose "Settings: $($Settings.Count)"
    Write-Verbose "Additional Settings: $($AdditionalSettings.Count)"
    if ($AdditionalSettings.Count -gt 0) {
        Write-Verbose "Combining additional settings with settings retrieved from Azure App Config"
        $Settings = $Settings + $AdditionalSettings
    }

    $settingsFile = $null

    try {

        $command = "az functionapp config appsettings set --name=""$Functionname"" --resource-group ""$ResourceGroup"" "
        if (-not([string]::IsNullOrWhiteSpace($Slot))) {
            $command += " --slot ""$Slot"" "
        }

        if ($Settings.Count -ge 1) {
            $settingsFile = [System.IO.Path]::GetRandomFileName()
            $ConvertToJsonParameters = @{}
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $ConvertToJsonParameters.Add("AsArray", $True)
            }
            $Settings | ConvertTo-Json @ConvertToJsonParameters | Set-Content -Path $settingsFile
            $command += " --settings '@$settingsFile'"
        }

        Write-Verbose "Invoking expression: $command"
        Write-Host "##octopus[stderr-progress]"
        $settingsUpdateResponse = Invoke-Expression -Command $command
        $ExitCode = $LastExitCode
        Write-Verbose "FunctionApp update ExitCode: $ExitCode"
        if ($ExitCode -ne 0) {
            throw "Error configuring appsettings for function app '$FunctionName'. ExitCode: $ExitCode"
        }
        Write-Host "##octopus[stderr-default]"
        if ($null -ne $settingsUpdateResponse) {
            Write-Host "Update of function '$FunctionName' was successful"
            try {
                $functionSettings = $settingsUpdateResponse | ConvertFrom-Json
                if ($null -ne $functionSettings) {
                    $settingsCount = @($functionSettings | Where-Object { $_.slotSetting -eq $False }).Count
                    $slotSettingsCount = @($functionSettings | Where-Object { $_.slotSetting -eq $True }).Count
                    Write-Verbose "Function '$FunctionName' has $settingsCount setting(s) and $slotSettingsCount slot setting(s)."
                }
            }
            catch {}
        }
        
    }
    catch { throw }
    finally {
        if (-not([string]::IsNullOrWhiteSpace($settingsFile))) {
            Write-Verbose "Removing temporary settings file $settingsFile"
            Remove-Item -Path $settingsFile -Force -ErrorAction Ignore
        }
        if (-not([string]::IsNullOrWhiteSpace($slotSettingsFile))) {
            Write-Verbose "Removing temporary slot settings file $slotSettingsFile"
            Remove-Item -Path $slotSettingsFile -Force -ErrorAction Ignore
        }
    }
}
else {
    Write-Host "No settings found to publish to the Azure App function"
}