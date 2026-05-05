[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Write-Output "Ensuring the Chocolatey package manager is installed..."

$chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\bin"
$chocInstalled = Test-Path "$chocolateyBin\choco.exe"

if (-not $chocInstalled) {
    Write-Output "Chocolatey not found, installing..."
    
    $installPs1 = ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    Invoke-Expression $installPs1
    
    Write-Output "Chocolatey installation complete."
} else {
    Write-Output "Chocolatey was found at $chocolateyBin and won't be reinstalled."
}
