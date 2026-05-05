[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\bin"
if(-not (Test-Path $chocolateyBin)) {
    Write-Output "Environment variable 'ChocolateyInstall' was not found in the system variables. Attempting to find it in the user variables..."
    $chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "User") + "\bin"
}

$choco = "$chocolateyBin\choco.exe"

if (-not (Test-Path $choco)) {
    throw "Chocolatey was not found at $chocolateyBin."
}

$chocoArgs = @('install')
if (-not $ChocolateyPackageId) {
    throw "Please specify the ID of an application package to install."
}
else {
    $chocoArgs += $ChocolateyPackageId -split ' '
}

$chocoVersion = & $choco --version
Write-Output "Running Chocolatey version $chocoVersion"

if (-not $ChocolateyPackageVersion) {
    Write-Output "Installing package(s) $ChocolateyPackageId from the Chocolatey package repository..."
} else {
    Write-Output "Installing package $ChocolateyPackageId version $ChocolateyPackageVersion from the Chocolatey package repository..."
    $chocoArgs += @('--version', $ChocolateyPackageVersion)
}

if([System.Version]::Parse($chocoVersion) -ge [System.Version]::Parse("0.9.8.33")) {
    Write-Output "Adding --yes to arguments passed to Chocolatey"
    $chocoArgs += @("--yes")
}

if (![String]::IsNullOrEmpty($ChocolateyCacheLocation)) {
    Write-Output "Using --cache-location $ChocolateyCacheLocation"
    $chocoArgs += @("--cache-location", "`"'$ChocolateyCacheLocation'`"")
}

if (![String]::IsNullOrEmpty($ChocolateySource)) {
    Write-Output "Using package --source $ChocolateySource"
    $chocoArgs += @('--source', "`"'$ChocolateySource'`"")
}

if (($ChocolateyNoProgress -eq 'True') -and ([System.Version]::Parse($chocoVersion) -ge [System.Version]::Parse("0.10.4"))) {
    Write-Output "Disabling download progress with --no-progress"
    $chocoArgs += @('--no-progress')
}

if (![String]::IsNullOrEmpty($ChocolateyOtherParameters)) {
	$chocoArgs += $ChocolateyOtherParameters -split ' '
}

# execute the command line
Write-Output "Running the command: $choco $chocoArgs"
& $choco $chocoArgs

if ($global:LASTEXITCODE -eq 3010) { 
	# ignore reboot required exit code
    Write-Output "A restart may be required for the package to work"
    $global:LASTEXITCODE = 0
}