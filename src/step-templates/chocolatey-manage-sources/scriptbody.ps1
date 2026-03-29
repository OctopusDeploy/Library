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

# You cannot use [version] with SemVer 2 versions
# this allows pre-release versions to still work by stripping everything after the '-' as we could have
# 0.10.15-beta-20200101. We are only interested in the major.minor.build version
$chocoVersion = ($chocoVersion -split '-')[0].ToString()

# default args
$chocoArgs = @('source', $ChocolateySourceAction, '--yes')

# we need a source name
if ([string]::IsNullOrEmpty($ChocolateySourceName)) {
    throw "To manage a source you need to provide a source name."
}
else {
	$chocoArgs += "--name=""'$ChocolateySourceName'"""
}

# we are adding a source - check all of the parameters
if ($ChocolateySourceAction -eq 'add') {
	if ([string]::IsNullOrEmpty($ChocolateySourceLocation)) {
		throw 'To add a source you need to provide a source location.'
	}
    else {
    	$chocoArgs += "--source=""'$ChocolateySourceLocation'"""
    }

    # source priority
    if (-not [string]::IsNullOrEmpty($ChocolateySourcePriority)) {
    	if ([version]$chocoVersion -ge [version]'0.9.9.9') {
    		$chocoArgs += "--priority=""'$ChocolateySourcePriority'"""
        }
        else {
        	Write-Warning 'To use a source priority you must have Chocolatey version 0.9.9.9 or later. Ignoring source priority.'
        }
    }

    # allow self service
    if ($ChocolateySourceAllowSelfService) {
    	$edition = & $choco
    	if ($edition -like '*Business*' -and [version]$chocoVersion -ge [version]'0.10.4') {
        	$chocoArgs += '--allow-self-service'
        }
        else {
        	Write-Warning 'To allow self service on a source you must have Chocolatey For Business version 0.10.4 or later. Ignoring allowing self service.'
        }
    }

    # allow admin only
    if ($ChocolateySourceEnableAdminOnly) {
        # we are not going to check for the Business Edition but the chocolatey.extension version need to check we have the chocolatey.extension installed
        $licensedExtension = & $choco list chocolatey.extension --exact --limit-output --local-only | ConvertFrom-Csv -Delimiter '|' -Header 'Name', 'Version'

        # lets get the major.minor.build licensed extension version by stripping any pre-release
        $licensedExtensionVersion = ($licensedExtension.Version -split '-')[0].ToString()
        if ((-not [string]::IsNullOrEmpty($licensedExtensionVersion)) -and ([version]$chocoVersion -ge [version]'0.10.8' -and [version]$licensedExtensionVersion -ge [version]'1.12.2')) {
        	$chocoArgs += '--enable-admin-only'
        }
        else {
        	Write-Warning 'To enable admin only on a source you must have Chocolatey For Business Licensed Extension (chocolatey.extension package) version 1.12.2 or later and Chocolatey version 0.10.8 or later. Ignoring admin only enablement.'
        }
	}

    # we need both a username and a password - if one is used without the other then throw
    if (($ChocolateySourceUsername -and -not $ChocolateySourcePassword) -or ($ChocolateySourcePassword -and -not $ChocolateySourceUsername)) {
    	throw 'If you are using an authenticated source you must provide both a username AND a password.'
    }
    elseif ($ChocolateySourceUsername -and $ChocolateySourcePassword) {
		$chocoArgs += @("--user=""'$ChocolateySourceUsername'""", "--password=""'$ChocolateySourcePassword'""")
    }

    # check if we have a certificate path
    if (-not [string]::IsNullOrEmpty($ChocolateySourceCertificatePath)) {
    	if (-not (Test-Path -Path $ChocolateySourceCertificatePath)) {
        	throw "The certificate at '$ChocolateySourceCertificatePath' does not exist. Please make sure the certificate exists on the target at the provided path."
        }

        $chocoArgs += "--cert=""'$ChocolateySourceCertificatePath'"""

        # if we have a password it can only be used with a certificate path
        if (-not [string]::IsNullOrEmpty($ChocolateySourceCertificatePassword)) {
			$chocoArgs += "--certpassword=""'$ChocolateySourceCertificatePassword'"""
        }
    }
    elseif (-not [string]::IsNullOrEmpty($ChocolateySourceCertificatePassword)) {
    	Write-Warning 'You have provided a client certificate password but no client certificate path. Ignoring client certificate password.'
    }
}

# finally add any other parameters
if (-not [string]::IsNullOrEmpty($ChocolateySourceOtherParameters)) {
	$chocoArgs += $ChocolateySourceOtherParameters -split ' '
}

# execute the command line
Write-Host "Running the command: $choco $chocoArgs"
& $choco $chocoArgs