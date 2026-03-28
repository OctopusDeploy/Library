$TheService = Get-Service $ServiceName -ErrorAction SilentlyContinue
if ($TheService)
{
    Write-Host "Windows Service ""$ServiceName"" found, removing service."
    if ($TheService.Status -eq "Running")
    {
        Write-Host "Stopping $ServiceName ..."
        $TheService.Stop()
    }
    sc.exe delete $TheService
    Write-Host "Service ""$ServiceName"" removed."
}
else
{
    Write-Host "Windows Service ""$ServiceName"" not found."
}
