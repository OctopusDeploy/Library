$ErrorActionPreference = 'Stop'

# Helper functions
###############################################################################

function ConvertTo-JwtBase64 {
    param (
        $Value
    )
    if ($Value -is [string]) {
        $ConvertedValue = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Value)) -replace '\+', '-' -replace '/', '_' -replace '='
    }
    elseif ($Value -is [byte[]]) {
        $ConvertedValue = [Convert]::ToBase64String($Value) -replace '\+', '-' -replace '/', '_' -replace '='
    }

    return $ConvertedValue
}

function ConvertTo-Subject {
    param ([string]$Subject, [string]$IdentityPrefix)
    return ConvertTo-Identity -IdentityValue $Subject -IdentityPrefix $IdentityPrefix
}

function ConvertTo-Groups {
    param ([string]$Groups, [string]$IdentityPrefix)
    return ConvertTo-Identity -IdentityValue $Groups -IdentityPrefix $IdentityPrefix
}

function ConvertTo-Identity {
    param (
        [string]$IdentityValue, 
        [string]$IdentityPrefix
    )
    $ServerUri = $OctopusParameters["Octopus.Web.ServerUri"].ToLower() -Replace "http://" -Replace "https://"
    $ProjectGroup = $OctopusParameters["Octopus.ProjectGroup.Name"].ToLower() -Replace " ", "-"
    $Project = $OctopusParameters["Octopus.Project.Name"].ToLower() -Replace " ", "-"
    $Environment = $OctopusParameters["Octopus.Environment.Name"].ToLower() -Replace " ", "-"
    $identity = ""
    switch ($VAULT_GENERATE_JWT_SUBJECT) {
        "serveruri" {
            $identity = $ServerUri
        }
        "projectgroup" {
            $identity = "$ServerUri/$ProjectGroup"
        }
        "project" {
            $identity = "$ServerUri/$ProjectGroup/$Project"
        }
        "environment" {
            $identity = "$ServerUri/$ProjectGroup/$Project/$Environment"
        }
    }
    if (![string]::IsNullOrWhiteSpace($IdentityPrefix)) {
        $identity = "$IdentityPrefix$identity"
    }
    return $identity
}

###############################################################################

# Variables
$VAULT_GENERATE_JWT_PRIVATE_KEY = $OctopusParameters["Vault.Generate.JWT.PrivateKey"]
$VAULT_GENERATE_JWT_ALGORITHM = $OctopusParameters["Vault.Generate.JWT.Signing.Algorithm"]
$VAULT_GENERATE_JWT_EXPIRES_MINS = $OctopusParameters["Vault.Generate.JWT.ExpiresAfterMinutes"]
$VAULT_GENERATE_JWT_ISSUER = $OctopusParameters["Vault.Generate.JWT.Issuer"]
$VAULT_GENERATE_JWT_SUBJECT = $OctopusParameters["Vault.Generate.JWT.Subject"]
$VAULT_GENERATE_JWT_GROUPS = $OctopusParameters["Vault.Generate.JWT.Groups"]
$VAULT_GENERATE_JWT_AUDIENCE = $OctopusParameters["Vault.Generate.JWT.Audience"]

# Optional 
$VAULT_GENERATE_JWT_IDENTITY_PREFIX = $OctopusParameters["Vault.Generate.JWT.IdentityPrefix"]

$subject = ConvertTo-Subject -Groups $VAULT_GENERATE_JWT_GROUPS -IdentityPrefix $VAULT_GENERATE_JWT_IDENTITY_PREFIX
$groups = ConvertTo-Groups -Groups $VAULT_GENERATE_JWT_GROUPS -IdentityPrefix $VAULT_GENERATE_JWT_IDENTITY_PREFIX

$audiences = @()
if (![string]::IsNullOrWhiteSpace($VAULT_GENERATE_JWT_AUDIENCE)) {
    @(($VAULT_GENERATE_JWT_AUDIENCE -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            $audiences += $_
        }
    }
}

# Validation
if ([string]::IsNullOrWhiteSpace($VAULT_GENERATE_JWT_PRIVATE_KEY)) {
    throw "Required parameter Vault.Generate.JWT.PrivateKey not specified."
}
if ([string]::IsNullOrWhiteSpace($VAULT_GENERATE_JWT_ALGORITHM)) {
    throw "Required parameter Vault.Generate.JWT.Signing.Algorithm not specified."
}
if ([string]::IsNullOrWhiteSpace($VAULT_GENERATE_JWT_EXPIRES_MINS)) {
    throw "Required parameter Vault.Generate.JWT.ExpiresAfterMinutes not specified."
}
if ([string]::IsNullOrWhiteSpace($VAULT_GENERATE_JWT_ISSUER)) {
    throw "Required parameter Vault.Generate.JWT.Issuer not specified."
}
if ($audiences.Length -le 0) {
    throw "Required parameter Vault.Generate.JWT.Audience not specified."
}
if ([string]::IsNullOrWhiteSpace($subject)) {
    throw "Required parameter Vault.Generate.JWT.Subject not specified."
}
if ([string]::IsNullOrWhiteSpace($groups)) {
    throw "Required parameter Vault.Generate.JWT.Groups not specified."
}


# Signing functions
###############################################################################

$RsaPrivateKey_Header = "-----BEGIN RSA PRIVATE KEY-----"
$RsaPrivateKey_Footer = "-----END RSA PRIVATE KEY-----"
$Pkcs8_PrivateKey_Header = "-----BEGIN PRIVATE KEY-----"
$Pkcs8_PrivateKey_Footer = "-----END PRIVATE KEY-----"

function ExtractPemData {
    param (
        [string]$Pem,
        [string]$Header,
        [string]$Footer
    )

    $Start = $Pem.IndexOf($Header) + $Header.Length
    $End = $Pem.IndexOf($Footer, $Start) - $Start
    $EncodedPem = ($Pem.Substring($Start, $End).Trim()) -Replace " ", "`n"
    
    $PemData = [Convert]::FromBase64String($EncodedPem)
    return [byte[]]$PemData
}

function DecodeIntSize {
    param (
        [System.IO.BinaryReader]$BinaryReader
    )
    
    [byte]$byteValue = $BinaryReader.ReadByte()
    
    # If anything other than 0x02, an ASN.1 integer follows.
    if ($byteValue -ne 0x02) {
        return 0;
    }
    
    $byteValue = $BinaryReader.ReadByte()
    # 0x81 == Data size in next byte.
    if ($byteValue -eq 0x81) { 
        $size = $BinaryReader.ReadByte()
    }
    # 0x82 == Data size in next 2 bytes.
    else {
        if ($byteValue -eq 0x82) {
            [byte]$high = $BinaryReader.ReadByte()
            [byte]$low = $BinaryReader.ReadByte()
            $byteValues = [byte[]]@($low, $high, 0x00, 0x00)
            $size = [System.BitConverter]::ToInt32($byteValues, 0)
        }
        else {
            # Otherwise, data size has already been read above.
            $size = $byteValue
        }
    }
    # Remove high-order zeros in data
    $byteValue = $BinaryReader.ReadByte()
    while ($byteValue -eq 0x00) {
        $byteValue = $BinaryReader.ReadByte()
        $size -= 1
    }

    $BinaryReader.BaseStream.Seek(-1, [System.IO.SeekOrigin]::Current) | Out-Null
    return $size
}

function PadByteArray {
    param (
        [byte[]]$Bytes,
        [int]$Size
    )

    if ($Bytes.Length -eq $Size) {
        return $Bytes
    }
    if ($Bytes.Length -gt $Size) {
        throw "Specified size '$Size' to pad is too small for byte array of size '$($Bytes.Length)'."
    }

    [byte[]]$PaddedBytes = New-Object Byte[] $Size
    [System.Array]::Copy($Bytes, 0, $PaddedBytes, $Size - $bytes.Length, $bytes.Length) | Out-Null
    return $PaddedBytes
}

function Compare-ByteArrays {
    param (
        [byte[]]$First,
        [byte[]]$Second
    )
    if ($First.Length -ne $Second.Length) {
        return $False
    }
    [int]$i = 0
    foreach ($byte in $First) {
        if ($byte -ne $Second[$i]) {
            return $False
        }
        $i = $i + 1
    }
    return $True
}

function CreateRSAFromPkcs8 {
    param (
        [byte[]]$KeyBytes
    )
    Write-Verbose "Reading RSA Pkcs8 private key bytes"

    # The encoded OID sequence for PKCS #1 rsaEncryption szOID_RSA_RSA = "1.2.840.113549.1.1.1"
    # this byte[] includes the sequence byte and terminal encoded null 
    [byte[]]$SeqOID = 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00
    [byte[]]$Seq = New-Object byte[] 15

    # Have to wrap $KeyBytes in another array :|
    $MemoryStream = New-Object System.IO.MemoryStream(, $KeyBytes) 
    $reader = New-Object System.IO.BinaryReader($MemoryStream)
    $StreamLength = [int]$MemoryStream.Length
    
    try {
        [UInt16]$Bytes = $reader.ReadUInt16()

        if ($Bytes -eq 0x8130) {
            $reader.ReadByte() | Out-Null
        }
        elseif ($Bytes -eq 0x8230) {
            $reader.ReadInt16() | Out-Null
        }
        else {
            return $null
        }
        
        [byte]$byteValue = $reader.ReadByte()

        if ($byteValue -ne 0x02) {
            return $null
        }

        $Bytes = $reader.ReadUInt16()

        if ($Bytes -ne 0x0001) {
            return $null
        }

        # Read the Sequence OID
        $Seq = $reader.ReadBytes(15)
        $SequenceMatches = Compare-ByteArrays -First $Seq -Second $SeqOID
        if ($SequenceMatches -eq $False) {
            Write-Verbose "Sequence OID doesnt match"
            return $null
        }

        $byteValue = $reader.ReadByte()
        # Next byte should be a Octet string
        if ($byteValue -ne 0x04) {
            return $null
        }
        # Read next byte / 2 bytes. 
        # Should be either: 0x81 or 0x82; otherwise it's the byte count.
        $byteValue = $reader.ReadByte()
        if ($byteValue -eq 0x81) {
            $reader.ReadByte() | Out-Null
        }
        else {
            if ($byteValue -eq 0x82) {
                $reader.ReadUInt16() | Out-Null
            }
        }

        # Remaining sequence *should* be the RSA Pkcs1 private Key bytes
        [byte[]]$RsaKeyBytes = $reader.ReadBytes([int]($StreamLength - $MemoryStream.Position))
        Write-Verbose "Attempting to create RSA object from remaining Pkcs1 bytes"
        $rsa = CreateRSAFromPkcs1 -KeyBytes $RsaKeyBytes
        return $rsa
    }
    catch {
        Write-Warning "CreateRSAFromPkcs8: Exception occurred - $($_.Exception.Message)"
        return $null
    }
    finally {
        if ($null -ne $reader) { $reader.Close() }
        if ($null -ne $MemoryStream) { $MemoryStream.Close() }
    }
}

function CreateRSAFromPkcs1 {
    param (
        [byte[]]$KeyBytes
    )
    Write-Verbose "Reading RSA Pkcs1 private key bytes"
    # Have to wrap $KeyBytes in another array :|
    $MemoryStream = New-Object System.IO.MemoryStream(, $KeyBytes) 
    $reader = New-Object System.IO.BinaryReader($MemoryStream)
    try {
               
        [UInt16]$Bytes = $reader.ReadUInt16()

        if ($Bytes -eq 0x8130) {
            $reader.ReadByte() | Out-Null
        }
        elseif ($Bytes -eq 0x8230) {
            $reader.ReadInt16() | Out-Null
        }
        else {
            return $null
        }
    
        $Bytes = $reader.ReadUInt16()
        if ($Bytes -ne 0x0102) {
            return $null
        }
    
        [byte]$byteValue = $reader.ReadByte()
        if ($byteValue -ne 0x00) {
            return $null
        }

        # Private key parameters are integer sequences.
        # For a summary of the RSA Parameters fields, 
        # See https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.rsaparameters#summary-of-fields
        
        $Modulus_Size = DecodeIntSize -BinaryReader $reader
        $Modulus = $reader.ReadBytes($Modulus_Size)

        $E_Size = DecodeIntSize -BinaryReader $reader
        $E = $reader.ReadBytes($E_Size)

        $D_Size = DecodeIntSize -BinaryReader $reader
        $D = $reader.ReadBytes($D_Size)

        $P_Size = DecodeIntSize -BinaryReader $reader
        $P = $reader.ReadBytes($P_Size)

        $Q_Size = DecodeIntSize -BinaryReader $reader
        $Q = $reader.ReadBytes($Q_Size)

        $DP_Size = DecodeIntSize -BinaryReader $reader
        $DP = $reader.ReadBytes($DP_Size)

        $DQ_Size = DecodeIntSize -BinaryReader $reader
        $DQ = $reader.ReadBytes($DQ_Size)

        $IQ_Size = DecodeIntSize -BinaryReader $reader
        $IQ = $reader.ReadBytes($IQ_Size)

        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
        $rsaParameters = New-Object System.Security.Cryptography.RSAParameters
        $rsaParameters.Modulus = $Modulus
        $rsaParameters.Exponent = $E
        $rsaParameters.P = $P
        $rsaParameters.Q = $Q
        # Some RSAParameter values dont play well with byte buffers having leading zeroes removed.
        $rsaParameters.D = PadByteArray -Bytes $D -Size $Modulus.Length
        $rsaParameters.DP = PadByteArray -Bytes $DP -Size $P.Length
        $rsaParameters.DQ = PadByteArray -Bytes $DQ -Size $Q.Length
        $rsaParameters.InverseQ = PadByteArray -Bytes $IQ -Size $Q.Length
        $rsa.ImportParameters($rsaParameters)

        Write-Verbose "Completed RSA object creation"
        return $rsa
    }
    catch {
        Write-Warning "CreateRSA-FromPkcs1: Exception occurred - $($_.Exception.Message)"
        return $null
    }
    finally {
        if ($null -ne $reader) { $reader.Close() }
        if ($null -ne $MemoryStream) { $MemoryStream.Close() }
    }
}

function CreateSigningKey {
    param (
        [string]$Key
    )
    try {
        $Key = $Key.Trim()
        switch -Wildcard($Key) {
            "$Pkcs8_PrivateKey_Header*" {
                $KeyBytes = ExtractPemData -PEM $Key -Header $Pkcs8_PrivateKey_Header -Footer $Pkcs8_PrivateKey_Footer
                $SigningKey = CreateRSAFromPkcs8 -KeyBytes $KeyBytes
                return $SigningKey
            }
            "$RsaPrivateKey_Header*" {
                $KeyBytes = ExtractPemData -PEM $Key -Header $RsaPrivateKey_Header -Footer $RsaPrivateKey_Footer
                $SigningKey = CreateRSAFromPkcs1 -KeyBytes $KeyBytes
                return $SigningKey
            }
            default {
                Write-Verbose "The PEM header could not be found. Accepted headers: 'BEGIN PRIVATE KEY', 'BEGIN RSA PRIVATE KEY'"
                return $null
            }
        }
    }
    catch {
        Write-Warning "Couldn't create signing key: $($_.Exception.Message)"
        return $null
    }
}

###############################################################################

# Local variables
$StepName = $OctopusParameters["Octopus.Step.Name"]
$OutputVariableName = "JWT"

Write-Verbose "Vault.Generate.JWT.Signing.Algorithm: $VAULT_GENERATE_JWT_ALGORITHM"
Write-Verbose "Vault.Generate.JWT.ExpiresAfterMinutes: $VAULT_GENERATE_JWT_EXPIRES_MINS"
Write-Verbose "Vault.Generate.JWT.Issuer: $VAULT_GENERATE_JWT_ISSUER"
Write-Verbose "Vault.Generate.JWT.Audience(s): $($audiences -Join ",")"
Write-Verbose "Vault.Generate.JWT.Subject: $subject"
Write-Verbose "Vault.Generate.JWT.Groups: $groups"
Write-Verbose "Vault.Generate.JWT.IdentityPrefix: $VAULT_GENERATE_JWT_IDENTITY_PREFIX"
Write-Verbose "Step Name: $StepName"

try {

    # Created + Expires
    $Created = (Get-Date).ToUniversalTime()
    $Expires = $Created.AddMinutes([int]$VAULT_GENERATE_JWT_EXPIRES_MINS)

    $createDate = [Math]::Floor([decimal](Get-Date($Created) -UFormat "%s"))
    $expiryDate = [Math]::Floor([decimal](Get-Date($Expires) -UFormat "%s"))

    $JwtHeader = @{
        alg = $VAULT_GENERATE_JWT_ALGORITHM;
        typ = "JWT";
    } | ConvertTo-Json -Compress
    
    $JwtPayload = [Ordered]@{
        iat = [long]$createDate;
        exp = [long]$expiryDate;
        iss = $VAULT_GENERATE_JWT_ISSUER;
        aud = $audiences;
        sub = $subject;
        groups = $groups;
    }

    $JwtPayload = $JwtPayload | ConvertTo-Json -Compress

    $base64Header = ConvertTo-JwtBase64 -Value $JwtHeader
    $base64Payload = ConvertTo-JwtBase64 -Value $JwtPayload

    $Jwt = $base64Header + '.' + $base64Payload

    $JwtBytes = [System.Text.Encoding]::UTF8.GetBytes($Jwt)
    $JwtSignature = $null
    
    switch ($VAULT_GENERATE_JWT_ALGORITHM) {
        "RS256" {
            try { 

                $rsa = CreateSigningKey -Key $VAULT_GENERATE_JWT_PRIVATE_KEY
                if ($null -eq $rsa) {
                    throw "Couldn't create RSA object"
                }
                $Signature = $rsa.SignData($JwtBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) 
                $JwtSignature = ConvertTo-JwtBase64 -Value $Signature
            }
            catch { throw "Signing with SHA256 and Pkcs1 padding failed using private key: $($_.Exception.Message)" }
            finally { if ($null -ne $rsa) { $rsa.Dispose() } }
            
        }
        "RS384" {
            try { 
                $rsa = CreateSigningKey -Key $VAULT_GENERATE_JWT_PRIVATE_KEY
                if ($null -eq $rsa) {
                    throw "Couldn't create RSA object"
                }
                $Signature = $rsa.SignData($JwtBytes, [Security.Cryptography.HashAlgorithmName]::SHA384, [Security.Cryptography.RSASignaturePadding]::Pkcs1) 
                $JwtSignature = ConvertTo-JwtBase64 -Value $Signature
            }
            catch { throw "Signing with SHA384 and Pkcs1 padding failed using private key: $($_.Exception.Message)" }
            finally { if ($null -ne $rsa) { $rsa.Dispose() } }
        }
        "RS512" {
            try { 
                $rsa = CreateSigningKey -Key $VAULT_GENERATE_JWT_PRIVATE_KEY
                if ($null -eq $rsa) {
                    throw "Couldn't create RSA object"
                }
                $Signature = $rsa.SignData($JwtBytes, [Security.Cryptography.HashAlgorithmName]::SHA512, [Security.Cryptography.RSASignaturePadding]::Pkcs1) 
                $JwtSignature = ConvertTo-JwtBase64 -Value $Signature
            }
            catch { throw "Signing with SHA512 and Pkcs1 padding failed using private key: $($_.Exception.Message)" }
            finally { if ($null -ne $rsa) { $rsa.Dispose() } }
        }
        default {
            throw "The algorithm is not one of the supported: 'RS256', 'RS384', 'RS512'"
        }
    }
    if ([string]::IsNullOrWhiteSpace($JwtSignature) -eq $True) {
        throw "JWT signature empty."
    }

    $Jwt = "$Jwt.$JwtSignature"
    Set-OctopusVariable -Name $OutputVariableName -Value $Jwt -Sensitive
    Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$OutputVariableName}"
}
catch {
    $ExceptionMessage = $_.Exception.Message
    $Message = "An error occurred generating a JWT: $ExceptionMessage"
    Write-Error $Message -Category InvalidResult
}