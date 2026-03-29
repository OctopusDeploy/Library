[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables
$VAULT_APPROLE_WRAPPED_SECRETID_ADDRESS = $OctopusParameters["Vault.AppRole.WrappedSecretID.VaultAddress"]
$VAULT_APPROLE_WRAPPED_SECRETID_API_VERSION = $OctopusParameters["Vault.AppRole.WrappedSecretID.ApiVersion"]
$VAULT_APPROLE_WRAPPED_SECRETID_NAMESPACE = $OctopusParameters["Vault.AppRole.WrappedSecretID.Namespace"]
$VAULT_APPROLE_WRAPPED_SECRETID_PATH = $OctopusParameters["Vault.AppRole.WrappedSecretID.AppRolePath"]
$VAULT_APPROLE_WRAPPED_SECRETID_ROLENAME = $OctopusParameters["Vault.AppRole.WrappedSecretID.RoleName"]
$VAULT_APPROLE_WRAPPED_SECRETID_TTL = $OctopusParameters["Vault.AppRole.WrappedSecretID.TTL"]
$VAULT_APPROLE_WRAPPED_SECRETID_TOKEN = $OctopusParameters["Vault.AppRole.WrappedSecretID.AuthToken"]

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_WRAPPED_SECRETID_ADDRESS)) {
   throw "Required parameter VAULT_APPROLE_WRAPPED_SECRETID_ADDRESS not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_WRAPPED_SECRETID_API_VERSION)) {
	throw "Required parameter VAULT_APPROLE_WRAPPED_SECRETID_API_VERSION not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_WRAPPED_SECRETID_PATH)) {
	throw "Required parameter VAULT_APPROLE_WRAPPED_SECRETID_AUTH_PATH not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_WRAPPED_SECRETID_ROLENAME)) {
	throw "Required parameter VAULT_APPROLE_WRAPPED_SECRETID_ROLENAME not specified"
}
if ([string]::IsNullOrWhiteSpace($VAULT_APPROLE_WRAPPED_SECRETID_TOKEN)) {
	throw "Required parameter VAULT_APPROLE_WRAPPED_SECRETID_TOKEN not specified"
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
            try {$response = $rawResponse | ConvertFrom-Json} catch {$response=$rawResponse}
            return $response
        }
    }
    else {
        return $RequestError.ErrorDetails.Message
    }
}
###############################################################################

$VAULT_APPROLE_WRAPPED_SECRETID_ADDRESS = $VAULT_APPROLE_WRAPPED_SECRETID_ADDRESS.TrimEnd('/')
$VAULT_APPROLE_WRAPPED_SECRETID_PATH = $VAULT_APPROLE_WRAPPED_SECRETID_PATH.TrimStart('/').TrimEnd('/')
$VAULT_APPROLE_WRAPPED_SECRETID_ROLENAME = $VAULT_APPROLE_WRAPPED_SECRETID_ROLENAME.TrimStart('/').TrimEnd('/')

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]

try
{
	$headers = @{
        "X-Vault-Token" = $VAULT_APPROLE_WRAPPED_SECRETID_TOKEN
        "X-Vault-Wrap-Ttl" = $VAULT_APPROLE_WRAPPED_SECRETID_TTL
    }
    if (-not [string]::IsNullOrWhiteSpace($VAULT_APPROLE_WRAPPED_SECRETID_NAMESPACE)) {
        Write-Verbose "Setting 'X-Vault-Namespace' header to: $VAULT_APPROLE_WRAPPED_SECRETID_NAMESPACE"
        $Headers.Add("X-Vault-Namespace", $VAULT_APPROLE_WRAPPED_SECRETID_NAMESPACE)
    }
    
    $uri = "$VAULT_APPROLE_WRAPPED_SECRETID_ADDRESS/$VAULT_APPROLE_WRAPPED_SECRETID_API_VERSION/$VAULT_APPROLE_WRAPPED_SECRETID_PATH/role/$([uri]::EscapeDataString($VAULT_APPROLE_WRAPPED_SECRETID_ROLENAME))/secret-id"
    Write-Verbose "Making Put request to $uri"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put
    
    if($null -ne $response) {
    	Set-OctopusVariable -Name "WrappedToken" -Value $response.wrap_info.token -Sensitive
        Set-OctopusVariable -Name "WrappedTokenCreationPath" -Value $response.wrap_info.creation_path -Sensitive
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.WrappedToken}"
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.WrappedTokenCreationPath}"
    }
    else {
    	Write-Error "Null or Empty response returned from Vault server" -Category InvalidResult
    }
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $ErrorBody = Get-WebRequestErrorBody -RequestError $_
    $Message = "An error occurred getting a wrapped secretid: $ExceptionMessage"
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