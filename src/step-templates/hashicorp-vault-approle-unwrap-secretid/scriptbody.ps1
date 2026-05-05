[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS = $OctopusParameters["Vault.AppRole.UnwrapSecretID.VaultAddress"]
$VAULT_APPROLE_UNWRAP_SECRETID_API_VERSION = $OctopusParameters["Vault.AppRole.UnwrapSecretID.ApiVersion"]
$VAULT_APPROLE_UNWRAP_SECRETID_TOKEN = $OctopusParameters["Vault.AppRole.UnwrapSecretID.WrappedToken"]

# Optional Variables
$VAULT_APPROLE_UNWRAP_SECRETID_NAMESPACE = $OctopusParameters["Vault.AppRole.UnwrapSecretID.Namespace"]
$VAULT_APPROLE_UNWRAP_SECRETID_TOKEN_CREATION_PATH = $OctopusParameters["Vault.AppRole.UnwrapSecretID.WrappedTokenCreationPath"]

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS)) {
    throw "Required parameter VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_UNWRAP_SECRETID_API_VERSION)) {
    throw "Required parameter VAULT_APPROLE_UNWRAP_SECRETID_API_VERSION not specified"
}

if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_UNWRAP_SECRETID_TOKEN)) {
    throw "Required parameter VAULT_APPROLE_UNWRAP_SECRETID_TOKEN not specified"
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
###############################################################################

$VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS = $VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS.TrimEnd('/')

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

try {

    Write-Verbose "X-Vault-Namespace header: $VAULT_APPROLE_UNWRAP_SECRETID_NAMESPACE"

    # Should we validate lookup token's creation path?
    if (![string]::IsNullOrWhiteSpace($VAULT_APPROLE_UNWRAP_SECRETID_TOKEN_CREATION_PATH)) {
        $uri = "$VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS/$VAULT_APPROLE_UNWRAP_SECRETID_API_VERSION/sys/wrapping/lookup"    
        $payload = @{
            token = $VAULT_APPROLE_UNWRAP_SECRETID_TOKEN
        }

        $Headers = @{}
        if (-not [string]::IsNullOrWhiteSpace($VAULT_APPROLE_UNWRAP_SECRETID_NAMESPACE)) {
            $Headers.Add("X-Vault-Namespace", $VAULT_APPROLE_UNWRAP_SECRETID_NAMESPACE)
        }

        Write-Verbose "Making Post request to $uri"
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body ($payload | ConvertTo-Json -Depth 10) -Headers $Headers

        if ($null -ne $response) {
            Write-Verbose "Validating Wrapped token creation path."
            $Lookup_CreationPath = $response.data.creation_path
            if ($VAULT_APPROLE_UNWRAP_SECRETID_TOKEN_CREATION_PATH -ne $Lookup_CreationPath) {
                throw "Supplied Wrapped token creation path failed lookup validation. Check the creation path value and retry."
            }
        }
        else {
            Write-Error "Null or Empty response returned from Vault server lookup" -Category InvalidResult
        }
    }

    # Call to unwrap secret id from wrapped token.
    $Headers = @{
        "X-Vault-Token" = $VAULT_APPROLE_UNWRAP_SECRETID_TOKEN
    }

    if (-not [string]::IsNullOrWhiteSpace($VAULT_APPROLE_UNWRAP_SECRETID_NAMESPACE)) {
        $Headers.Add("X-Vault-Namespace", $VAULT_APPROLE_UNWRAP_SECRETID_NAMESPACE)
    }
    
    $uri = "$VAULT_APPROLE_UNWRAP_SECRETID_ADDRESS/$VAULT_APPROLE_UNWRAP_SECRETID_API_VERSION/sys/wrapping/unwrap"
    Write-Verbose "Making Post request to $uri"
    $response = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Post
    
    if ($null -ne $response) {
        Set-OctopusVariable -Name "UnwrappedSecretID" -Value $response.data.secret_id -Sensitive
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.UnwrappedSecretID}"
    }
    else {
        Write-Error "Null or Empty response returned from Vault server unwrap" -Category InvalidResult
    }
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $ErrorBody = Get-WebRequestErrorBody -RequestError $_
    $Message = "An error occurred unwrapping secretid: $ExceptionMessage"
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