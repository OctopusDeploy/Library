[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$VAULT_JWT_LOGIN_ADDRESS = $OctopusParameters["Vault.JWT.Login.VaultAddress"]
$VAULT_JWT_LOGIN_API_VERSION = $OctopusParameters["Vault.JWT.Login.ApiVersion"]
$VAULT_JWT_LOGIN_AUTH_PATH = $OctopusParameters["Vault.JWT.Login.AuthPath"]
$VAULT_JWT_LOGIN_ROLE = $OctopusParameters["Vault.JWT.Login.Role"]
$VAULT_JWT_LOGIN_TOKEN = $OctopusParameters["Vault.JWT.Token"]

# Optional
$VAULT_JWT_LOGIN_NAMESPACE = $OctopusParameters["Vault.JWT.Login.Namespace"]

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_JWT_LOGIN_ADDRESS)) {
    throw "Required parameter Vault.JWT.Login.VaultAddress not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_JWT_LOGIN_API_VERSION)) {
    throw "Required parameter Vault.JWT.Login.ApiVersion not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_JWT_LOGIN_AUTH_PATH)) {
    throw "Required parameter Vault.JWT.Login.AuthPath not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_JWT_LOGIN_ROLE)) {
    throw "Required parameter Vault.JWT.Login.Role not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_JWT_LOGIN_TOKEN)) {
    throw "Required parameter Vault.JWT.Token not specified"
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

$VAULT_JWT_LOGIN_ADDRESS = $VAULT_JWT_LOGIN_ADDRESS.TrimEnd('/')
$VAULT_JWT_LOGIN_AUTH_PATH = $VAULT_JWT_LOGIN_AUTH_PATH.TrimStart('/').TrimEnd('/')

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

try {
    $payload = @{
        role = $VAULT_JWT_LOGIN_ROLE;
        jwt  = $VAULT_JWT_LOGIN_TOKEN;
    }

    $Headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($VAULT_JWT_LOGIN_NAMESPACE)) {
        Write-Verbose "Setting 'X-Vault-Namespace' header to: $VAULT_JWT_LOGIN_NAMESPACE"
        $Headers.Add("X-Vault-Namespace", $VAULT_JWT_LOGIN_NAMESPACE)
    }
    
    $uri = "$VAULT_JWT_LOGIN_ADDRESS/$VAULT_JWT_LOGIN_API_VERSION/$VAULT_JWT_LOGIN_AUTH_PATH/login"
    Write-Verbose "Making request to $uri"
    $response = Invoke-RestMethod -Method Post -Uri $uri -Body ($payload | ConvertTo-Json -Depth 10) -Headers $Headers
    if ($null -ne $response) {
        Set-OctopusVariable -Name "JWTAuthToken" -Value $response.auth.client_token -Sensitive
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.JWTAuthToken}"
    }
    else {
        Write-Error "Null or Empty response returned from Vault server" -Category InvalidResult
    }
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $ErrorBody = Get-WebRequestErrorBody -RequestError $_
    $Message = "An error occurred logging in with JWT: $ExceptionMessage"
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