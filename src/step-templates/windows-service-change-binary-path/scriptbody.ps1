$TheService = Get-Service $ServiceName -ErrorAction SilentlyContinue
if ($TheService)
{
    Write-Host "Windows Service ""$ServiceName"" found, changing path."
    sc.exe config $TheService binPath= $BinaryPath
    Write-Host "Service ""$ServiceName"" path changed to ""$BinaryPath"", restart service to use new path."
}
else
{
    Write-Host "Windows Service ""$ServiceName"" not found."
}
