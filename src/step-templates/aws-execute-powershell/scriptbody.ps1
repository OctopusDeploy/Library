Write-Output "Ensuring the Chocolatey package manager is installed..."

$chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\bin"
$chocolateyExe = "$chocolateyBin\choco.exe"
$chocInstalled = Test-Path $chocolateyExe

if (-not $chocInstalled) {
  Write-Output "Chocolatey not found, installing..."

  $installPs1 = ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
  Invoke-Expression $installPs1

  Write-Output "Chocolatey installation complete."
} else {
  Write-Output "Chocolatey was found at $chocolateyBin and won't be reinstalled."
}

$ChocolateyPackageId = 'awstools.powershell'

if (-not $ChocolateyPackageId) {
  throw "Please specify the ID of an application package to install."
}

if (-not $ChocolateyPackageVersion) {
  Write-Output "Installing package $ChocolateyPackageId from the Chocolatey package repository..."
  & $chocolateyExe install $ChocolateyPackageId
} else {
  Write-Output "Installing package $ChocolateyPackageId version $ChocolateyPackageVersion from the Chocolatey package repository..."
  & $chocolateyExe install $ChocolateyPackageId --version $ChocolateyPackageVersion
}

Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs AWSKeyProfile

Initialize-AWSDefaults -ProfileName AWSKeyProfile -Region $Region


Invoke-Expression $AWSScript