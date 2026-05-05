[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$VAULT_APPROLE_LOGIN_ADDRESS = $OctopusParameters["Vault.AppRole.Login.VaultAddress"]
$VAULT_APPROLE_LOGIN_API_VERSION = $OctopusParameters["Vault.AppRole.Login.ApiVersion"]
$VAULT_APPROLE_LOGIN_APPROLE_PATH = $OctopusParameters["Vault.AppRole.Login.AppRolePath"]
$VAULT_APPROLE_LOGIN_ROLEID = $OctopusParameters["Vault.AppRole.Login.RoleID"]
$VAULT_APPROLE_LOGIN_SECRETID = $OctopusParameters["Vault.AppRole.Login.SecretID"]

# Optional variables
$VAULT_APPROLE_LOGIN_NAMESPACE = $OctopusParameters["Vault.AppRole.Login.Namespace"]

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_LOGIN_ADDRESS)) {
    throw "Required parameter VAULT_APPROLE_LOGIN_ADDRESS not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_LOGIN_API_VERSION)) {
    throw "Required parameter VAULT_APPROLE_LOGIN_API_VERSION not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_LOGIN_APPROLE_PATH)) {
    throw "Required parameter VAULT_APPROLE_LOGIN_APPROLE_PATH not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_LOGIN_ROLEID)) {
    throw "Required parameter VAULT_APPROLE_LOGIN_ROLEID not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_LOGIN_SECRETID)) {
    throw "Required parameter VAULT_APPROLE_LOGIN_SECRETID not specified"
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

$VAULT_APPROLE_LOGIN_ADDRESS = $VAULT_APPROLE_LOGIN_ADDRESS.TrimEnd('/')
$VAULT_APPROLE_LOGIN_APPROLE_PATH = $VAULT_APPROLE_LOGIN_APPROLE_PATH.TrimStart('/').TrimEnd('/')

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

try {
    $payload = @{
        role_id   = $VAULT_APPROLE_LOGIN_ROLEID
        secret_id = $VAULT_APPROLE_LOGIN_SECRETID
    }

    $Headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($VAULT_APPROLE_LOGIN_NAMESPACE)) {
        Write-Verbose "Setting 'X-Vault-Namespace' header to: $VAULT_APPROLE_LOGIN_NAMESPACE"
        $Headers.Add("X-Vault-Namespace", $VAULT_APPROLE_LOGIN_NAMESPACE)
    }

    $uri = "$VAULT_APPROLE_LOGIN_ADDRESS/$VAULT_APPROLE_LOGIN_API_VERSION/$([uri]::EscapeDataString($VAULT_APPROLE_LOGIN_APPROLE_PATH))/login"
    Write-Verbose "Making request to $uri"
    $response = Invoke-RestMethod -Method Post -Uri $uri -Body ($payload | ConvertTo-Json -Depth 10) -Headers $Headers
    
    if ($null -ne $response) {
        Set-OctopusVariable -Name "AppRoleAuthToken" -Value $response.auth.client_token -Sensitive
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.AppRoleAuthToken}"
    }
    else {
        Write-Error "Null or Empty response returned from Vault server" -Category InvalidResult
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