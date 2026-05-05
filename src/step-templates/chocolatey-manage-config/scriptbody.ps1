[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\bin"
if(-not (Test-Path $chocolateyBin)) {
    Write-Host "Environment variable 'ChocolateyInstall' was not found in the system variables. Attempting to find it in the user variables..."
    $chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "User") + "\bin"
}

$choco = "$chocolateyBin\choco.exe"

if (-not (Test-Path $choco)) {
    throw "Chocolatey was not found at $chocolateyBin."
}

# Report the actual version here
$chocoVersion = & $choco --version
Write-Host "Running Chocolatey version $chocoVersion"

# default args
$chocoArgs = @('config', $ChocolateyConfigAction, '--yes')

# we need a source name
if ([string]::IsNullOrEmpty($ChocolateyConfigName)) {
    throw "To manage a feature,  you need to provide a feature name."
}
else {
	$chocoArgs += "--name=""'$ChocolateyConfigName'"""
}

if ($ChocolateyConfigAction -eq 'set') {
    if ([string]::IsNullOrEmpty($ChocolateyConfigValue)) {
        throw 'To set the config, you need to provide a value.'
    }
    
    $chocoArgs += "--value=""'$ChocolateyConfigValue'"""
}

# finally add any other parameters
if (-not [string]::IsNullOrEmpty($ChocolateyConfigOtherParameters)) {
	$chocoArgs += $ChocolateyConfigOtherParameters -split ' '
}

# execute the command line
Write-Host "Running the command: $choco $chocoArgs"
& $choco $chocoArgs