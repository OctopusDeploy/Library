[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$ConjurUrl = $OctopusParameters["CyberArk.Conjur.RetrieveSecrets.Url"]
$ConjurAccount = $OctopusParameters["CyberArk.Conjur.RetrieveSecrets.Account"]
$ConjurLogin = $OctopusParameters["CyberArk.Conjur.RetrieveSecrets.Login"]
$ConjurApiKey = $OctopusParameters["CyberArk.Conjur.RetrieveSecrets.ApiKey"]
$ConjurSecretVariables = $OctopusParameters["CyberArk.Conjur.RetrieveSecrets.SecretVariables"]
$PrintVariableNames = $OctopusParameters["CyberArk.Conjur.RetrieveSecrets.PrintVariableNames"]
$ConjurTrustCertificate = [System.Convert]::ToBoolean($OctopusParameters['CyberArk.Conjur.TrustCertificate'])

# Validation
if ([string]::IsNullOrWhiteSpace($ConjurUrl)) {
    throw "Required parameter CyberArk.Conjur.RetrieveSecrets.Url not specified"
}
if ([string]::IsNullOrWhiteSpace($ConjurAccount)) {
    throw "Required parameter CyberArk.Conjur.RetrieveSecrets.Account not specified"
}
if ([string]::IsNullOrWhiteSpace($ConjurLogin)) {
    throw "Required parameter CyberArk.Conjur.RetrieveSecrets.Login not specified"
}
if ([string]::IsNullOrWhiteSpace($ConjurApiKey)) {
    throw "Required parameter CyberArk.Conjur.RetrieveSecrets.ApiKey not specified"
}
if ([string]::IsNullOrWhiteSpace($ConjurSecretVariables)) {
    throw "Required parameter CyberArk.Conjur.RetrieveSecrets.SecretVariables not specified"
}

### Helper functions

# This function creates a URI and prevents Urls that have been Url encoded from being re-encoded.
# Typically this happens on Windows (dynamic) workers in Octopus, and not PS Core.
# Helpful background - https://stackoverflow.com/questions/25596564/percent-encoded-slash-is-decoded-before-the-request-dispatch
# Function based from https://github.com/IISResetMe/PSdotNETRuntimeHacks/blob/trunk/Set-DontUnescapePathDotsAndSlashes.ps1
function New-DontUnescapePathDotsAndSlashes-Uri {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]$SourceUri
    )

    $uri = New-Object System.Uri $SourceUri

    # If running PS Core, not affected
    if ($PSEdition -eq "Core") {
        return $uri
    }

    # Retrieve the private Syntax field from the uri class,
    # this is our indirect reference to the attached parser
    $syntaxFieldInfo = $uri.GetType().GetField('m_Syntax', 'NonPublic,Instance')
    if (-not $syntaxFieldInfo) {
        throw [System.MissingFieldException]"'m_Syntax' field not found"
    }

    # Retrieve the private Flags field from the parser class,
    # this is the value we're looking to update at runtime
    $flagsFieldInfo = [System.UriParser].GetField('m_Flags', 'NonPublic,Instance')
    if (-not $flagsFieldInfo) {
        throw [System.MissingFieldException]"'m_Flags' field not found"
    }

    # Retrieve the actual instances
    $uriParser = $syntaxFieldInfo.GetValue($uri)
    $uriSyntaxFlags = $flagsFieldInfo.GetValue($uriParser)

    # Define the bit flags we want to remove
    $UnEscapeDotsAndSlashes = 0x2000000
    $SimpleUserSyntax = 0x20000

    # Clear the flags that we don't want
    $uriSyntaxFlags = [int]$uriSyntaxFlags -band -bnot($UnEscapeDotsAndSlashes)
    $uriSyntaxFlags = [int]$uriSyntaxFlags -band -bnot($SimpleUserSyntax)

    # Overwrite the existing Flags field
    $flagsFieldInfo.SetValue($uriParser, $uriSyntaxFlags)

    return $uri
}

function Get-WebRequestErrorBody {
    param (
        $RequestError
    )
    $rawResponse = ""
    # Powershell < 6 you can read the Exception
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($RequestError.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($RequestError.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $rawResponse = $reader.ReadToEnd()
        }
    }
    else {
        $rawResponse = $RequestError.ErrorDetails.Message
    }

    try { $response = $rawResponse | ConvertFrom-Json } catch { $response = $rawResponse }
    return $response
}

function Format-SecretName {
    [CmdletBinding()]
    Param(
        [string] $Name,
        [string] $Version
    )
    $displayName = "'$Name'"
    if (![string]::IsNullOrWhiteSpace($Version)) {
        $displayName += " (v:$($Version))"
    }
    return $displayName
}

function Invoke-CyberArk-Rest-Method
{
  # define parameters
  [CmdletBinding()]
  param(
    $Url,
    $Method,
    $Headers,
    $Body,
    $TrustCertificate
  )

  # define working variables
  $invokeArguments = @{
    Uri = $Url
    Method = $Method
  }

  # Check for the presence of variables
  if (![string]::IsNullOrWhitespace($Headers))
  {
    $invokeArguments.Add("Headers", $Headers)
  }

  if (![string]::IsNullOrWhitespace($Body))
  {
    $invokeArguments.Add("Body", $Body)
  }

  if ($TrustCertificate -eq $true)
  {
    $invokeArguments.Add("SkipCertificateCheck", $TrustCertificate)
  }

  return Invoke-RestMethod @invokeArguments
}

### End Helper function

$Secrets = @()
$VariablesCreated = 0
$StepName = $OctopusParameters["Octopus.Step.Name"]
$ConjurUrl = $ConjurUrl.TrimEnd("/")


# Extract secret names
@(($ConjurSecretVariables -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"
        $secretDefinition = ($_ -Split "\|")
        $secretName = $secretDefinition[0].Trim()
        $secretNameAndVersion = ($secretName -Split " ")
        $secretVersion = ""
        if ($secretNameAndVersion.Count -gt 1) {
            $secretName = $secretNameAndVersion[0].Trim()
            $secretVersion = $secretNameAndVersion[1].Trim()
        }
        if ([string]::IsNullOrWhiteSpace($secretName)) {
            throw "Unable to establish secret name from: '$($_)'"
        }

        $UriEscapedName = [uri]::EscapeDataString($secretName)
        $VariableIdPrefix = "$($ConjurAccount):variable"

        $secret = [PsCustomObject]@{
            Name                 = $secretName
            UriEscapedName       = $uriEscapedName
            Version              = $secretVersion
            VariableName         = if (![string]::IsNullOrWhiteSpace($secretDefinition[1])) { $secretDefinition[1].Trim() } else { "" }
            VariableId           = "$($VariableIdPrefix):$($secretName)"
            UriEscapedVariableId = "$($VariableIdPrefix):$($UriEscapedName)"
        }
        $Secrets += $secret
    }
}
$SecretsWithVersionSpecified = @($Secrets | Where-Object { ![string]::IsNullOrWhiteSpace($_.Version) })

Write-Verbose "Conjur Url: $ConjurUrl"
Write-Verbose "Conjur Account: $ConjurAccount"
Write-Verbose "Conjur Login: $ConjurLogin"
Write-Verbose "Conjur API Key: ********"
Write-Verbose "Secrets to retrieve: $($Secrets.Count)"
Write-Verbose "Secrets with Version specified: $($SecretsWithVersionSpecified.Count)"
Write-Verbose "Print variables: $PrintVariableNames"

try {

    $headers = @{
        "Content-Type"    = "application/json"; 
        "Accept-Encoding" = "base64"
    }

    $body = $ConjurApiKey
    $loginUriSegment = [uri]::EscapeDataString($ConjurLogin)
    $authnUri = New-DontUnescapePathDotsAndSlashes-Uri -SourceUri "$ConjurUrl/authn/$ConjurAccount/$loginUriSegment/authenticate"
    #$authToken = Invoke-RestMethod -Uri $authnUri -Method Post -Headers $headers -Body $body
    $authToken = Invoke-CyberArk-Rest-Method -Url $authnUri -Method Post -Headers $headers -Body $body -TrustCertificate $ConjurTrustCertificate
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $ErrorBody = Get-WebRequestErrorBody -RequestError $_
    $Message = "An error occurred logging in to Conjur: $ExceptionMessage"
    $AdditionalDetail = ""
    if (![string]::IsNullOrWhiteSpace($ErrorBody)) {
        if ($null -ne $ErrorBody.error) {
            $AdditionalDetail = "$($ErrorBody.error.code) - $($ErrorBody.error.message)"
        }
        else {
            $AdditionalDetail += $ErrorBody
        }
    }
    if (![string]::IsNullOrWhiteSpace($AdditionalDetail)) {
        $Message += "`nDetail: $AdditionalDetail"
    }
    
    Write-Error $Message -Category AuthenticationError
}

if ([string]::IsNullOrWhiteSpace($authToken)) {
    Write-Error "Null or Empty token!"
    return
}

# Set token auth header
$headers = @{
    "Authorization" = "Token token=`"$($authToken)`""; 
}

if ($SecretsWithVersionSpecified.Count -gt 0) {
    Write-Verbose "Retrieving secrets individually as at least one has a version specified."
    foreach ($secret in $Secrets) {
        try {
            $name = $secret.Name
            $uriEscapedName = $secret.UriEscapedName
            $secretVersion = $secret.Version
            $variableName = $secret.VariableName
            $displayName = Format-SecretName -Name $name -Version $secretVersion

            if ([string]::IsNullOrWhiteSpace($variableName)) {
                $variableName = "$($name.Trim().Replace("/","."))"
            }
            $secretUri = "$ConjurUrl/secrets/$ConjurAccount/variable/$uriEscapedName"
            if (![string]::IsNullOrWhiteSpace($secretVersion)) {
                $secretUri += "?version=$($secretVersion)"
            }
            $secretUri = New-DontUnescapePathDotsAndSlashes-Uri -SourceUri "$secretUri"
            Write-Verbose "Retrieving Secret $displayName"
            #$secretValue = Invoke-RestMethod -Uri $secretUri -Method Get -Headers $headers
            $secretValue = Invoke-CyberArk-Rest-Method -Url $secretUri -Method Get -Headers $headers -TrustCertificate $ConjurTrustCertificate

            if ([string]::IsNullOrWhiteSpace($secretValue)) {
                Write-Error "Error: Secret $displayName not found or has no versions."
                break;
            }
    
            Set-OctopusVariable -Name $variableName -Value $secretValue -Sensitive
    
            if ($PrintVariableNames -eq $True) {
                Write-Output "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
            }
            $VariablesCreated += 1
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            $ErrorBody = Get-WebRequestErrorBody -RequestError $_
            $Message = "An error occurred retrieving secret $($displayName) from Conjur: $ExceptionMessage"
            $AdditionalDetail = ""
            if (![string]::IsNullOrWhiteSpace($ErrorBody)) {
                if ($null -ne $ErrorBody.error) {
                    $AdditionalDetail = "$($ErrorBody.error.code) - $($ErrorBody.error.message)"
                }
                else {
                    $AdditionalDetail += $ErrorBody
                }
            }
        
            if (![string]::IsNullOrWhiteSpace($AdditionalDetail)) {
                $Message += "`nDetail: $AdditionalDetail"
            }
    
            Write-Error $Message -Category ReadError
            break;
        }
    }
}
else {
    Write-Verbose "Retrieving secrets by batch as no versions specified."
    $uriEscapedVariableIds = @($Secrets | ForEach-Object { "$($_.UriEscapedVariableId)" }) -Join ","

    try {    
        $secretsUri = New-DontUnescapePathDotsAndSlashes-Uri -SourceUri "$ConjurUrl/secrets?variable_ids=$($uriEscapedVariableIds)"
        #$secretValues = Invoke-RestMethod -Uri $secretsUri -Method Get -Headers $headers
        $secretValues = Invoke-CyberArk-Rest-Method -Url $secretsUri -Method Get -Headers $headers -TrustCertificate $ConjurTrustCertificate
        $secretKeyValues = $secretValues | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty "Name"
        foreach ($secret in $Secrets) {
            $name = $secret.Name
            $variableId = $secret.VariableId
            $variableName = $secret.VariableName

            Write-Verbose "Extracting Secret '$($name)' from Conjur batched response"

            if ([string]::IsNullOrWhiteSpace($variableName)) {
                $variableName = "$($name.Trim().Replace("/","."))"
            }
            if ($secretKeyValues -inotcontains $variableId) {
                Write-Error "Secret '$name' not found in Conjur response."
                return
            }
            
            $variableValue = $secretValues.$variableId
            Set-OctopusVariable -Name $variableName -Value $variableValue -Sensitive

            if ($PrintVariableNames -eq $True) {
                Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
            }
            $VariablesCreated += 1
        }
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        $ErrorBody = Get-WebRequestErrorBody -RequestError $_
        $Message = "An error occurred retrieving batched secrets from Conjur: $ExceptionMessage"
        $AdditionalDetail = ""
        if (![string]::IsNullOrWhiteSpace($ErrorBody)) {
            if ($null -ne $ErrorBody.error) {
                $AdditionalDetail = "$($ErrorBody.error.code) - $($ErrorBody.error.message)"
            }
            else {
                $AdditionalDetail += $ErrorBody
            }
        }
        if (![string]::IsNullOrWhiteSpace($AdditionalDetail)) {
            $Message += "`nDetail: $AdditionalDetail"
        }
        
        Write-Error $Message -Category AuthenticationError
    }
}

Write-Host "Created $variablesCreated output variables"