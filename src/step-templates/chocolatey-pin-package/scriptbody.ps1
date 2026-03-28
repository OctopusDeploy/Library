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

# check we have required parameters
if (-not $ChocolateyPackagePinId) {
    throw "Please specify the ID of an application package to install."
}

$chocoVersion = & $choco --version
Write-Output "Running Chocolatey version $chocoVersion"

# base arguments to use with choco.exe
$chocoBaseArgs = @('pin', $ChocolateyPackagePinAction)

# this parameter only works in Chocolatey licensed editions
if ($ChocolateyPackagePinReason) {
 	# determine if this is a licensed edition
	$edition = & $choco
    if ($edition -like '*Business*' -and [version]$chocoVersion -ge [version]'1.12.2') {
    	Write-Output "Using reason '$ChocolateyPackagePinReason' when pinning packages."
    	$chocoBaseArgs += "--reason=""'$ChocolateyPackagePinReason'"""
    }
	else {
    	Write-Output "Using a reason for a package pin only works with Chocolatey For Business licensed editions. Ignoring the pin reason '$ChocolateyPackagePinReason'."
	}
}

if ($ChocolateyPackagePinVersion) {
	$chocoBaseArgs += "--version=$ChocolateyPackagePinVersion"
}

$chocoPackages = $ChocolateyPackagePinId -split ' '
ForEach ($package in $chocoPackages) {
	Write-Output "Pinning Chocolatey package $package."
    $chocoArgs = $chocoBaseArgs + @("--name=""'$package'""")
    
    # execute the command line
	Write-Output "Running the command: $choco $chocoArgs"
	& $choco $chocoArgs
}