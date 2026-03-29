[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$VAULT_LDAP_LOGIN_ADDRESS = $OctopusParameters["Vault.LDAP.Login.VaultAddress"]
$VAULT_LDAP_LOGIN_API_VERSION = $OctopusParameters["Vault.LDAP.Login.ApiVersion"]
$VAULT_LDAP_LOGIN_NAMESPACE = $OctopusParameters["Vault.LDAP.Login.Namespace"]
$VAULT_LDAP_LOGIN_AUTH_PATH = $OctopusParameters["Vault.LDAP.Login.AuthPath"]
$VAULT_LDAP_LOGIN_USERNAME = $OctopusParameters["Vault.LDAP.Login.Username"]
$VAULT_LDAP_LOGIN_PASSWORD = $OctopusParameters["Vault.LDAP.Login.Password"]

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_LDAP_LOGIN_ADDRESS)) {
    throw "Required parameter VAULT_LDAP_LOGIN_ADDRESS not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_LDAP_LOGIN_API_VERSION)) {
    throw "Required parameter VAULT_LDAP_LOGIN_API_VERSION not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_LDAP_LOGIN_AUTH_PATH)) {
    throw "Required parameter VAULT_LDAP_LOGIN_AUTH_PATH not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_LDAP_LOGIN_USERNAME)) {
    throw "Required parameter VAULT_LDAP_LOGIN_USERNAME not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_LDAP_LOGIN_PASSWORD)) {
    throw "Required parameter VAULT_LDAP_LOGIN_PASSWORD not specified"
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

$VAULT_LDAP_LOGIN_ADDRESS = $VAULT_LDAP_LOGIN_ADDRESS.TrimEnd('/')
$VAULT_LDAP_LOGIN_AUTH_PATH = $VAULT_LDAP_LOGIN_AUTH_PATH.TrimStart('/').TrimEnd('/')

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

try {
    $payload = @{
        password = $VAULT_LDAP_LOGIN_PASSWORD
    }
    
    $Headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($VAULT_LDAP_LOGIN_NAMESPACE)) {
        Write-Verbose "Setting 'X-Vault-Namespace' header to: $VAULT_LDAP_LOGIN_NAMESPACE"
        $Headers.Add("X-Vault-Namespace", $VAULT_LDAP_LOGIN_NAMESPACE)
    }
    
    $uri = "$VAULT_LDAP_LOGIN_ADDRESS/$VAULT_LDAP_LOGIN_API_VERSION/$VAULT_LDAP_LOGIN_AUTH_PATH/login/$([uri]::EscapeDataString($VAULT_LDAP_LOGIN_USERNAME))"
    Write-Verbose "Making request to $uri"
    $response = Invoke-RestMethod -Method Post -Uri $uri -Body ($payload | ConvertTo-Json -Depth 10) -Headers $Headers
    if ($null -ne $response) {
        Set-OctopusVariable -Name "LDAPAuthToken" -Value $response.auth.client_token -Sensitive
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.LDAPAuthToken}"
    }
    else {
        Write-Error "Null or Empty response returned from Vault server" -Category InvalidResult
    }
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $ErrorBody = Get-WebRequestErrorBody -RequestError $_
    $Message = "An error occurred logging in with LDAP: $ExceptionMessage"
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