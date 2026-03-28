$FilePath          = "#{FilePath}"
$TrustedIssuerName = "#{TrustedIssuerName}"
$MetadataUri       = "#{MetadataUri}"


[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq")

# because Octo calls powershell steps in a stupid manor...
$charGT = [System.Text.Encoding]::ASCII.GetString( @(62) )

function Get-Thumbprints($MetadataUri) {
    $MetadataTxt = Invoke-WebRequest -Uri $MetadataUri
    $MetadataXml = [xml]($MetadataTxt.Content)
    
    $outval = @()
    # new certs
    
    $MetadataXml.EntityDescriptor.IDPSSODescriptor.KeyDescriptor | ? { $_.use -eq "signing" } | % {
        $Cert_Bytes = [System.Convert]::FromBase64String( $_.KeyInfo.X509Data.X509Certificate )
        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( , $Cert_Bytes ) # powershell is stupid about arrays
        Write-Host "Found certificate for [$($_.use)] : [$($cert.NotBefore.ToString("yyyyMMdd")) - $($cert.NotAfter.ToString("yyyyMMdd"))] : Thumbprint [$($Cert.Thumbprint)] for Subject [$($Cert.Subject)]"
        $outval += $Cert.Thumbprint
    }
    return $outval
}

function Get-TextIndex([string]$text, [int]$LineNumber = 0, [int]$LinePosition = 0) {
    # Ported from : https://github.com/futurist/src-location/blob/master/index.js  function locationToIndex
    # NOTE: diff from source to address bug. Test-GetTextIndex validates the changes.
    $strLF = [char]10 # \n
    $strCR = [char]13 # \r
    $idx   = -1       # text index
    $lc    = 1        # Line Count
    for($i = 0; $lc -lt $LineNumber -and $i -lt $text.Length; $i++) {
        $idx++
        $c = $text[$i] # cur char
        if ($c -eq $strLF -or $c -eq $strCR) {
            $lc++
            if ($c -eq $strCR -and $text[$i + 1] -eq $strLF) { # DOS CRLF
                $i++
                $idx++
            }
        }
    }
    return $idx + $LinePosition
}

function Replace-TrustedIssuerThumbprints($FilePath, $TrustedIssuerName, $Thumbprints) {
    # Load the file twice - once as text for manipulation, once as XML for xpath and positions
    $fileText      = [System.IO.File]::ReadAllText($FilePath)
    $fileXml       = [System.Xml.Linq.XDocument]::Load($FilePath, [System.Xml.Linq.LoadOptions]::SetLineInfo -bor [System.Xml.Linq.LoadOptions]::PreserveWhitespace )
    $IdpsXml       = $fileXml.Descendants("configuration")[0].Descendants("system.identityModel")[0].Descendants("identityConfiguration")[0].Descendants("issuerNameRegistry")[0].Descendants("trustedIssuers")[0].Descendants("add")

    # Figure out which elements to manipulate... First delete from the bottom up, then replace the top-most element
    $IdpMatches    = $IdpsXml | ? { $_.Attribute("name").Value -eq $TrustedIssuerName } | Sort-Object -Property LineNumber, LinePosition -Descending
    $IdpsToDelete  = $IdpMatches | Select-Object -First ($IdpMatches.Count - 1)
    $IdpsToReplace = $IdpMatches | Select-Object -Last 1

    # Delete from the bottom up, so that the LineNumber/LinePosition remain valid during the manipulation
    foreach ($IdP in $IdpsToDelete) {
        Write-Host ( "DEL [{0}:{1}] {2}" -f $IdP.LineNumber, $IdP.LinePosition, $IdP.ToString() )

        $fileIdxOpen  = Get-TextIndex -text $fileText -LineNumber $IdP.LineNumber -LinePosition ( $IdP.LinePosition - 1 )
        $fileIdxClose = $fileText.IndexOf($charGT, $fileIdxOpen) + 1 # add one to include the closing &gt;
        $fileSubstr   = $fileText.Substring($fileIdxOpen, $fileIdxClose - $fileIdxOpen)
        Write-Host ( "    [$fileIdxOpen .. $fileIdxClose] : $fileSubstr" )

        $fileIdxPrior = $fileText.LastIndexOf($charGT, $fileIdxOpen) + 1
        $fileText     = $fileText.Remove($fileIdxPrior, $fileIdxClose - $fileIdxPrior)
    }
    # Replace the top-most element with each thumbprint
    foreach ($IdP in $IdpsToReplace) {
        Write-Host ( "FIX [{0}:{1}] {2}" -f $IdP.LineNumber, $IdP.LinePosition, $IdP.ToString() )

        $fileIdxOpen  = Get-TextIndex -text $fileText -LineNumber $IdP.LineNumber -LinePosition ( $IdP.LinePosition - 1 )
        $fileIdxClose = $fileText.IndexOf($charGT, $fileIdxOpen) + 1 # add one to include the closing &gt;
        $fileSubstr   = $fileText.Substring($fileIdxOpen, $fileIdxClose - $fileIdxOpen)
        Write-Host ( "    [$fileIdxOpen .. $fileIdxClose] : $fileSubstr" )

        $fileIdxPrior = $fileText.LastIndexOf($charGT, $fileIdxOpen) + 1
        $ElementDelim = $fileText.Substring($fileIdxPrior, $fileIdxOpen - $fileIdxPrior)
        Write-Host ( "   -[{0} .. {1}]" -f $fileIdxPrior, $fileIdxClose )
        $fileText     = $fileText.Remove($fileIdxPrior, $fileIdxClose - $fileIdxPrior)
        foreach ($Thumbprint in $Thumbprints) {
            $newAttribs = [System.Xml.Linq.XAttribute[]]@(
                                ( New-Object System.Xml.Linq.XAttribute("thumbprint", $Thumbprint       ) ),
                                ( New-Object System.Xml.Linq.XAttribute("name"      , $TrustedIssuerName) )
                            )
            $newValue = ( New-Object System.Xml.Linq.XElement("add", $newAttribs) ).ToString()
            $fileText = $fileText.Insert($fileIdxPrior, $ElementDelim + $newValue)
        }
    }
    return $fileText
}


$ThumbPrints       = Get-Thumbprints -MetadataUri $MetadataUri
$fileContent       = Replace-TrustedIssuerThumbprints -FilePath $FilePath -TrustedIssuerName $TrustedIssuerName -Thumbprints $ThumbPrints
[System.IO.File]::WriteAllText($FilePath, $fileContent)
