$ErrorActionPreference = 'Stop'

# Variables
$GENERATE_JWT_PRIVATE_KEY = $OctopusParameters["Generate.JWT.PrivateKey"]
$GENERATE_JWT_ALGORITHM = $OctopusParameters["Generate.JWT.Signing.Algorithm"]
$GENERATE_JWT_EXPIRES_MINS = $OctopusParameters["Generate.JWT.ExpiresAfterMinutes"]

# Optional 
$GENERATE_JWT_ISSUER = $OctopusParameters["Generate.JWT.Issuer"]
$GENERATE_JWT_SUBJECT = $OctopusParameters["Generate.JWT.Subject"]
$GENERATE_JWT_GROUPS = $OctopusParameters["Generate.JWT.Groups"]
$GENERATE_JWT_AUDIENCE = $OctopusParameters["Generate.JWT.Audience"]
$GENERATE_JWT_TTL = $OctopusParameters["Generate.JWT.TTL"]
$GENERATE_JWT_MAX_TTL = $OctopusParameters["Generate.JWT.TTL.Max"]
$GENERATE_JWT_PRIVATE_CLAIM_NAME = $OctopusParameters["Generate.JWT.PrivateClaim.Name"]
$GENERATE_JWT_PRIVATE_CLAIM_VALUE = $OctopusParameters["Generate.JWT.PrivateClaim.Value"]

# Validation
if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_PRIVATE_KEY)) {
    throw "Required parameter Generate.JWT.PrivateKey not specified."
}
if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_ALGORITHM)) {
    throw "Required parameter Generate.JWT.Signing.Algorithm not specified."
}
if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_EXPIRES_MINS)) {
    throw "Required parameter Generate.JWT.ExpiresAfterMinutes not specified."
}
if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_AUDIENCE)) {
    throw "Required parameter Generate.JWT.Audience not specified."
}

# Optional fields that require validation
if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_PRIVATE_CLAIM_NAME) -eq $False) {
    if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_PRIVATE_CLAIM_VALUE)) {
        throw "A private claim name has been specified with no value found in Generate.JWT.PrivateClaim.Value."
    }
}

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

###############################################################################

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
    $EncodedPem = ($Pem.Substring($Start, $End).Trim())  -Replace " ", "`n"
    
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
$audiences = @()
if (![string]::IsNullOrWhiteSpace($GENERATE_JWT_AUDIENCE)) {
    @(($GENERATE_JWT_AUDIENCE -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            $audiences += $_
        }
    }
}

$groups = @()
if (![string]::IsNullOrWhiteSpace($GENERATE_JWT_GROUPS)) {
    @(($GENERATE_JWT_GROUPS -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            $groups += $_
        }
    }
}

$StepName = $OctopusParameters["Octopus.Step.Name"]
$OutputVariableName = "JWT"

Write-Verbose "Generate.JWT.Signing.Algorithm: $GENERATE_JWT_ALGORITHM"
Write-Verbose "Generate.JWT.ExpiresAfterMinutes: $GENERATE_JWT_EXPIRES_MINS"
Write-Verbose "Generate.JWT.Issuer: $GENERATE_JWT_ISSUER"
Write-Verbose "Generate.JWT.Subject: $GENERATE_JWT_SUBJECT"
Write-Verbose "Generate.JWT.Audience(s): $($audiences -Join ",")"
Write-Verbose "Generate.JWT.Group(s): $($groups -Join ",")"
Write-Verbose "Generate.JWT.TTL: $GENERATE_JWT_TTL"
Write-Verbose "Generate.JWT.TTL.Max: $GENERATE_JWT_MAX_TTL"
Write-Verbose "Generate.JWT.PrivateClaim.Name: $GENERATE_JWT_PRIVATE_CLAIM_NAME"
Write-Verbose "Generate.JWT.PrivateClaim.Value: $GENERATE_JWT_PRIVATE_CLAIM_VALUE"
Write-Verbose "Step Name: $StepName"

try {

    # Created + Expires
    $Created = (Get-Date).ToUniversalTime()
    $Expires = $Created.AddMinutes([int]$GENERATE_JWT_EXPIRES_MINS)

    $createDate = [Math]::Floor([decimal](Get-Date($Created) -UFormat "%s"))
    $expiryDate = [Math]::Floor([decimal](Get-Date($Expires) -UFormat "%s"))

    $JwtHeader = @{
        alg = $GENERATE_JWT_ALGORITHM;
        typ = "JWT";
    } | ConvertTo-Json -Compress
    
    $JwtPayload = [Ordered]@{
        iat = [long]$createDate;
        exp = [long]$expiryDate;
    }

    # Check for optional issuer: https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.1
    if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_ISSUER) -eq $False) {
        $JwtPayload | Add-Member -NotePropertyName iss -NotePropertyValue $GENERATE_JWT_ISSUER
    }

    # Check for optional subject: https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.2
    if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_SUBJECT) -eq $False) {
        $JwtPayload | Add-Member -NotePropertyName sub -NotePropertyValue $GENERATE_JWT_SUBJECT
    }

    # Check for optional audience: https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3
    if ($audiences.Length -gt 0) {
        $JwtPayload | Add-Member -NotePropertyName aud -NotePropertyValue $audiences
    }
    # Check for optional "groups" field
    if ($groups.Length -gt 0) {
        $JwtPayload | Add-Member -NotePropertyName groups -NotePropertyValue $groups
    }

    # Check for optional ttl field
    if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_TTL) -eq $False) {
        $JwtPayload | Add-Member -NotePropertyName ttl -NotePropertyValue $GENERATE_JWT_TTL
    }
    # Check for optional max_ttl field
    if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_MAX_TTL) -eq $False) {
        $JwtPayload | Add-Member -NotePropertyName max_ttl -NotePropertyValue $GENERATE_JWT_MAX_TTL
    }

    # Check for an optional private claim name and value: https://datatracker.ietf.org/doc/html/rfc7519#section-4.3
    if ([string]::IsNullOrWhiteSpace($GENERATE_JWT_PRIVATE_CLAIM_NAME) -eq $False) {
        $JwtPayload | Add-Member -NotePropertyName $GENERATE_JWT_PRIVATE_CLAIM_NAME -NotePropertyValue $GENERATE_JWT_PRIVATE_CLAIM_VALUE
    } 

    $JwtPayload = $JwtPayload | ConvertTo-Json -Compress

    $base64Header = ConvertTo-JwtBase64 -Value $JwtHeader
    $base64Payload = ConvertTo-JwtBase64 -Value $JwtPayload

    $Jwt = $base64Header + '.' + $base64Payload

    $JwtBytes = [System.Text.Encoding]::UTF8.GetBytes($Jwt)
    $JwtSignature = $null
    
    switch ($GENERATE_JWT_ALGORITHM) {
        "RS256" {
            try { 

                $rsa = CreateSigningKey -Key $GENERATE_JWT_PRIVATE_KEY
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
                $rsa = CreateSigningKey -Key $GENERATE_JWT_PRIVATE_KEY
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
                $rsa = CreateSigningKey -Key $GENERATE_JWT_PRIVATE_KEY
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