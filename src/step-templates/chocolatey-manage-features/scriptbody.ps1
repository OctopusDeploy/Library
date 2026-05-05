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
$chocoArgs = @('feature', $ChocolateyFeatureAction, '--yes')

# we need a source name
if ([string]::IsNullOrEmpty($ChocolateyFeatureName)) {
    throw "To manage a feature,  you need to provide a feature name."
}

# finally add any other parameters
if (-not [string]::IsNullOrEmpty($ChocolateyFeatureOtherParameters)) {
	$chocoArgs += $ChocolateyFeatureOtherParameters -split ' '
}

$featureNames = $ChocolateyFeatureName -split ' '
ForEach ($name in $featureNames) {
	$cmdArgs = $chocoArgs + "--name=""'$name'"""

    # execute the command line
    Write-Host "Running the command: $choco $cmdArgs"
    & $choco $cmdArgs
}