if(-not (Test-Path $env:SystemRoot\System32\wevtutil.exe))
{
    throw "wevtutil.exe could not be found"
}

if(-not (Test-Path $ManifestFile))
{
    throw "Manifest $manifest could not be found"
}

if(-not (Test-Path $ResourceFile))
{
    throw "Resource file $ResourceFile could not be found"
}

if(-not (Test-Path $MessageFile))
{
    throw "Message file $MessageFile could not be found"
}

& "$env:SystemRoot\System32\wevtutil.exe" im $ManifestFile /rf:$ResourceFile /mf:$MessageFile