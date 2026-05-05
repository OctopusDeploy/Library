### Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Required Variables
$VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.VaultAddress"]
$VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.ApiVersion"]
$VAULT_RETRIEVE_KV_V2_SECRETS_TOKEN = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.AuthToken"]
$VAULT_RETRIEVE_KV_V2_SECRETS_PATH = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.SecretsPath"]
$VAULT_RETRIEVE_KV_V2_SECRETS_METHOD = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.RetrievalMethod"]
$VAULT_RETRIEVE_KV_V2_SECRETS_RECURSIVE = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.RecursiveSearch"]
$VAULT_RETRIEVE_KV_V2_PRINT_VARIABLE_NAMES = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.PrintVariableNames"]

# Optional variables
$VAULT_RETRIEVE_KV_V2_SECRETS_FIELD_VALUES = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.FieldValues"]
$VAULT_RETRIEVE_KV_V2_SECRETS_SECRET_VERSION = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.SecretVersion"]
$VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE = $OctopusParameters["Vault.Retrieve.KV.V2.Secrets.Namespace"]

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS)) {
    throw "Required parameter VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION)) {
    throw "Required parameter VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_TOKEN)) {
    throw "Required parameter VAULT_RETRIEVE_KV_V2_SECRETS_TOKEN not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_PATH)) {
    throw "Required parameter VAULT_RETRIEVE_KV_V2_SECRETS_PATH not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_METHOD)) {
    throw "Required parameter VAULT_RETRIEVE_KV_V2_SECRETS_METHOD not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_RECURSIVE)) {
    throw "Required parameter VAULT_RETRIEVE_KV_V2_SECRETS_RECURSIVE not specified"
}

# Helper functions
###############################################################################
function Get-WebRequestErrorBody {
    param (
        $RequestError
    )

    # Powershell < 6 you can read the Exception
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($RequestError.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($RequestError.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $rawResponse = $reader.ReadToEnd()
            $response = ""
            try { $response = $rawResponse | ConvertFrom-Json } catch { $response = $rawResponse }
            return $response
        }
    }
    else {
        return $RequestError.ErrorDetails.Message
    }
}

function Get-VaultSecret {
    param (
        [string]$SecretEnginePath,
        [string]$SecretPath,
        $Fields
    )
    try {
        # Local variables
        $VariablesCreated = 0
        $FieldsSpecified = ($Fields.Count -gt 0)
        $SecretPath = $SecretPath.TrimStart("/")
        $WorkingPath = "$($SecretEnginePath)/$($SecretPath)"
        $RequestPath = "$SecretEnginePath/data/$($SecretPath)"

        $uri = "$VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS/$VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION/$([uri]::EscapeDataString($RequestPath))"
        if (![string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_SECRET_VERSION) -and $RetrieveMultipleKeys -eq $False) {
            $uri = "$($uri)?version=$VAULT_RETRIEVE_KV_V2_SECRETS_SECRET_VERSION"
        }
        
        $headers = @{"X-Vault-Token" = $VAULT_RETRIEVE_KV_V2_SECRETS_TOKEN }
        
        if (-not [string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE)) {
            $Headers.Add("X-Vault-Namespace", $VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE)           
        }
        
        Write-Verbose "Making request to $uri"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET

        if ($null -ne $response) {
            if ($FieldsSpecified -eq $True) {
                foreach ($field in $Fields) {
                    $fieldName = $field.Name
                    $fieldVariableName = $field.VariableName
                    $fieldValue = $response.data.data.$fieldName

                    if ($null -ne $fieldValue) {
                        if ([string]::IsNullOrWhiteSpace($fieldVariableName)) {
                            $fieldVariableName = "$($WorkingPath.Replace("/",".")).$($fieldName.Trim())"
                        }
                        
                        Set-OctopusVariable -Name $fieldVariableName -Value $fieldValue -Sensitive
                        if ($VAULT_RETRIEVE_KV_V2_PRINT_VARIABLE_NAMES -eq $True) {
                            Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$fieldVariableName}"
                        }
                        $VariablesCreated += 1
                    }
                }
            } 
            # No fields specified, iterate through each one.
            else {
                $secretFieldNames = $response.data.data | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty "Name"
                foreach ($fieldName in $secretFieldNames) {
                    $fieldVariableName = "$($WorkingPath.Replace("/",".")).$($fieldName.Trim())"
                    $fieldValue = $response.data.data.$fieldName
                    
                    Set-OctopusVariable -Name $fieldVariableName -Value $fieldValue -Sensitive
                    if ($VAULT_RETRIEVE_KV_V2_PRINT_VARIABLE_NAMES -eq $True) {
                        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$fieldVariableName}"
                    }
                    $VariablesCreated += 1
                }
            }
            return $VariablesCreated
        }  
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        $ErrorBody = Get-WebRequestErrorBody -RequestError $_
        $Message = "An error occurred logging in with AppRole: $ExceptionMessage"
        $AdditionalDetail = ""
        if (![string]::IsNullOrWhiteSpace($ErrorBody)) {
            if ($null -ne $ErrorBody.errors) {
                $AdditionalDetail = $ErrorBody.errors -Join ","   
            }
            else {
                $errorDetails = $null
                try { $errorDetails = ConvertFrom-Json $ErrorBody } catch {}
                $AdditionalDetail += if ($null -ne $errorDetails) { $errorDetails.errors -Join "," } else { $ErrorBody } 
            }
        }
        
        if (![string]::IsNullOrWhiteSpace($AdditionalDetail)) {
            $Message += "`n`tDetail: $AdditionalDetail"
        }
    
        Write-Error $Message -Category ConnectionError
    }
}

function List-VaultSecrets {
    param (
        [string]$SecretEnginePath,
        [string]$SecretPath
    )
    try {
        $SecretPath = $SecretPath.TrimStart("/")
        $RequestPath = "$SecretEnginePath/metadata/$SecretPath"

        # Vault uses the 'LIST' HTTP verb, which is only supported in PowerShell 6.0+ using -CustomMethod.
        # Adding ?list=true will allow support for Windows Desktop PowerShell.
        # See https://www.vaultproject.io/api#api-operations for further details/
        $uri = "$VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS/$VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION/$([uri]::EscapeDataString($RequestPath))?list=true"
        $headers = @{"X-Vault-Token" = $VAULT_RETRIEVE_KV_V2_SECRETS_TOKEN }
        if (-not [string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE)) {
            $Headers.Add("X-Vault-Namespace", $VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE)
        }

        Write-Verbose "Making request to $uri"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET

        return $response
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        $ErrorBody = Get-WebRequestErrorBody -RequestError $_
        $Message = "An error occurred logging in with AppRole: $ExceptionMessage"
        $AdditionalDetail = ""
        if (![string]::IsNullOrWhiteSpace($ErrorBody)) {
            if ($null -ne $ErrorBody.errors) {
                $AdditionalDetail = $ErrorBody.errors -Join ","   
            }
            else {
                $errorDetails = $null
                try { $errorDetails = ConvertFrom-Json $ErrorBody } catch {}
                $AdditionalDetail += if ($null -ne $errorDetails) { $errorDetails.errors -Join "," } else { $ErrorBody } 
            }
        }
        
        if (![string]::IsNullOrWhiteSpace($AdditionalDetail)) {
            $Message += "`n`tDetail: $AdditionalDetail"
        }
    
        Write-Error $Message -Category ConnectionError
    }
}

function Recursive-GetVaultSecrets {
    param(
        [string]$SecretEnginePath,
        [string]$SecretPath
    )
    $VariablesCreated = 0
    $SecretPath = $SecretPath.TrimStart("/")
    $SecretPath = $SecretPath.TrimEnd("/")

    Write-Verbose "Executing Recursive-GetVaultSecrets"
    
    # Get list of secrets for path
    $VaultKeysResponse = List-VaultSecrets -SecretEnginePath $SecretEnginePath -SecretPath $SecretPath 
    
    if ($null -ne $VaultKeysResponse) {
        $keys = $VaultKeysResponse.data.keys
        if ($null -ne $keys) {
            $secretKeys = $keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) -and !$_.EndsWith("/") }
            foreach ($secretKey in $secretKeys) {
                $secretKeyPath = "$($SecretPath)/$secretKey"
                $variablesCreated += Get-VaultSecret -SecretEnginePath $SecretEnginePath -SecretPath $secretKeyPath -Fields $Fields
            }

            if ($VAULT_RETRIEVE_KV_V2_SECRETS_RECURSIVE -eq $True) {
                $folderKeys = $keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) -and $_.EndsWith("/") }
                foreach ($folderKey in $folderKeys) {
                    $Depth = $Depth += 1
                    $folderPath = "$($SecretPath)/$folderKey"
                    $VariablesCreated += Recursive-GetVaultSecrets -SecretEnginePath $SecretEnginePath -SecretPath $folderPath
                }
            }
        }
    }
    return $VariablesCreated
}

###############################################################################
$VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS = $VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS.TrimEnd('/')
$VAULT_RETRIEVE_KV_V2_SECRETS_PATH = $VAULT_RETRIEVE_KV_V2_SECRETS_PATH.TrimStart('/')

# Local variables
$RetrieveMultipleKeys = $VAULT_RETRIEVE_KV_V2_SECRETS_METHOD.ToUpper().Trim() -ne "GET"
$SecretPathItems = ($VAULT_RETRIEVE_KV_V2_SECRETS_PATH -Split "/")
$SecretEnginePath = ($SecretPathItems | Select-Object -First 1)
$SecretPath = ($SecretPathItems | Select-Object -Skip 1) -Join "/"
$StepName = $OctopusParameters["Octopus.Step.Name"]

$Fields = @()
$VariablesCreated = 0

if (![string]::IsNullOrWhiteSpace($VAULT_RETRIEVE_KV_V2_SECRETS_FIELD_VALUES)) {
    
    @(($VAULT_RETRIEVE_KV_V2_SECRETS_FIELD_VALUES -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            Write-Verbose "Working on: '$_'"
            $fieldDefinition = ($_ -Split "\|")
            $name = $fieldDefinition[0].Trim()
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw "Unable to establish fieldname from: '$($_)'"
            }
            $field = [PsCustomObject]@{
                Name         = $name
                VariableName = if (![string]::IsNullOrWhiteSpace($fieldDefinition[1])) { $fieldDefinition[1].Trim() } else { "" }
            }
            $Fields += $field
        }
    }
}
$FieldsSpecified = ($Fields.Count -gt 0)

Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS: $VAULT_RETRIEVE_KV_V2_SECRETS_ADDRESS"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION: $VAULT_RETRIEVE_KV_V2_SECRETS_API_VERSION"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_TOKEN: '********'"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_PATH: $VAULT_RETRIEVE_KV_V2_SECRETS_PATH"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_METHOD: $VAULT_RETRIEVE_KV_V2_SECRETS_METHOD"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_RECURSIVE: $VAULT_RETRIEVE_KV_V2_SECRETS_RECURSIVE"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_SECRET_VERSION: $VAULT_RETRIEVE_KV_V2_SECRETS_SECRET_VERSION"
Write-Verbose "VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE: $VAULT_RETRIEVE_KV_V2_SECRETS_NAMESPACE"
Write-Verbose "RetrieveMultipleKeys: $RetrieveMultipleKeys"
Write-Verbose "Fields Specified: $($FieldsSpecified)"
Write-Verbose "Engine Path: $SecretEnginePath"
Write-Verbose "Secret Path: $SecretPath"

$variablesCreated = 0

if ($RetrieveMultipleKeys -eq $false) {
    $variablesCreated += Get-VaultSecret -SecretEnginePath $SecretEnginePath -SecretPath $SecretPath -Fields $Fields
}
else {
    $variablesCreated = Recursive-GetVaultSecrets -SecretEnginePath $SecretEnginePath -SecretPath $SecretPath -Depth 0
}
Write-Host "Created $variablesCreated output variables"