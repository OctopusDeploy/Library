if(-not (Test-Path $env:SystemRoot\System32\wevtutil.exe))
{
    throw "wevtutil.exe could not be found"
}

if(-not (Test-Path $ManifestFile))
{
    Write-Host "Skipping manifest $ManifestFile because it does not exist" 
    Exit 0
}

& "$env:SystemRoot\System32\wevtutil.exe" um $ManifestFile