## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------

$webSiteName = $OctopusParameters['WebSiteName']
$applicationPoolName = $OctopusParameters["ApplicationPoolName"]
$bindingProtocol = $OctopusParameters["BindingProtocol"]
$bindingPort = $OctopusParameters["BindingPort"]
$bindingIpAddress = $OctopusParameters["BindingIpAddress"]
$bindingHost = $OctopusParameters["BindingHost"]
$bindingSslThumbprint = $OctopusParameters["BindingSslThumbprint"]
$webRoot = $OctopusParameters["WebRoot"]
$iisAuthentication = $OctopusParameters["IisAuthentication"]
$webSiteStart = $OctopusParameters["WebsiteStart"]


$anonymousAuthentication = "Anonymous"
$basicAuthentication = "Basic"
$windowsAuthentication = "Windows"
## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------
# Helper for validating input parameters
function Validate-Parameter($foo, [string[]]$validInput, $parameterName) {
    Write-Host "${parameterName}: ${foo}"
    if (! $foo) {
        throw "$parameterName cannot be empty, please specify a value"
    }
    
    if ($validInput) {
        @($foo) | % { 
                if ($validInput -notcontains $_) {
                    throw "'$_' is not a valid input for '$parameterName'"
                }
             }  
        }   
}

# Helper to run a block with a retry if things go wrong
$maxFailures = 5
$sleepBetweenFailures = Get-Random -minimum 1 -maximum 4
function Execute-WithRetry([ScriptBlock] $command) {
	$attemptCount = 0
	$operationIncomplete = $true

	while ($operationIncomplete -and $attemptCount -lt $maxFailures) {
		$attemptCount = ($attemptCount + 1)

		if ($attemptCount -ge 2) {
			Write-Output "Waiting for $sleepBetweenFailures seconds before retrying..."
			Start-Sleep -s $sleepBetweenFailures
			Write-Output "Retrying..."
		}

		try {
			& $command

			$operationIncomplete = $false
		} catch [System.Exception] {
			if ($attemptCount -lt ($maxFailures)) {
				Write-Output ("Attempt $attemptCount of $maxFailures failed: " + $_.Exception.Message)
			
			}
			else {
			    throw "Failed to execute command"
			}
		}
	}
}

## --------------------------------------------------------------------------------------
## Validate Input
## --------------------------------------------------------------------------------------

Write-Output "Validating paramters..."
Validate-Parameter $webSiteName -parameterName "Web Site Name"
Validate-Parameter $applicationPoolName -parameterName "Application Pool Name"
Validate-Parameter $bindingProtocol -validInput @("HTTP", "HTTPS") -parameterName "Protocol"
Validate-Parameter $bindingPort -parameterName "Port"
if($bindingProtocol.ToLower() -eq "https") {
    Validate-Parameter $bindingSslThumbprint -parameterName "SSL Thumbprint"
}

$enabledIisAuthenticationOptions = $iisAuthentication -split '\s*[,;]\s*'

Validate-Parameter $enabledIisAuthenticationOptions -validInput @($anonymousAuthentication, $basicAuthentication, $windowsAuthentication) -parameterName "IIS Authentication"

$enableAnonymous = $enabledIisAuthenticationOptions -contains $anonymousAuthentication
$enableBasic = $enabledIisAuthenticationOptions -contains $basicAuthentication
$enableWindows = $enabledIisAuthenticationOptions -contains $windowsAuthentication

## --------------------------------------------------------------------------------------
## Configuration
## --------------------------------------------------------------------------------------
if (! $webRoot) {
	$webRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\InetStp' -name PathWWWRoot).PathWWWRoot
}
$webRoot = (resolve-path $webRoot).ProviderPath
Validate-Parameter $webRoot -parameterName "Relative Home Directory"

$bindingInformation = "${bindingIpAddress}:${bindingPort}:${bindingHost}"

Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue

$wsBindings = new-object System.Collections.ArrayList
$wsBindings.Add(@{ protocol=$bindingProtocol;bindingInformation=$bindingInformation }) | Out-Null
if (! [string]::IsNullOrEmpty($bindingSslThumbprint)) {
    $wsBindings.Add(@{ thumbprint=$bindingSslThumbprint }) | Out-Null
    
    $sslCertificateThumbprint = $bindingSslThumbprint.Trim()
    Write-Output "Finding SSL certificate with thumbprint $sslCertificateThumbprint"
    
    $certificate = Get-ChildItem Cert:\LocalMachine -Recurse | Where-Object { $_.Thumbprint -eq $sslCertificateThumbprint -and $_.HasPrivateKey -eq $true } | Select-Object -first 1
    if (! $certificate) 
    {
        throw "Could not find certificate under Cert:\LocalMachine with thumbprint $sslCertificateThumbprint. Make sure that the certificate is installed to the Local Machine context and that the private key is available."
    }

    Write-Output ("Found certificate: " + $certificate.Subject)

    if ((! $bindingIpAddress) -or ($bindingIpAddress -eq '*')) {
        $bindingIpAddress = "0.0.0.0"
    }
    $port = $bindingPort

    $sslBindingsPath = ("IIS:\SslBindings\" + $bindingIpAddress + "!" + $port)

	Execute-WithRetry { 
		$sslBinding = get-item $sslBindingsPath -ErrorAction SilentlyContinue
		if (! $sslBinding) {
			New-Item $sslBindingsPath -Value $certificate | Out-Null
		} else {
			Set-Item $sslBindingsPath -Value $certificate | Out-Null
		}		
	}
}

## --------------------------------------------------------------------------------------
## Run
## --------------------------------------------------------------------------------------

pushd IIS:\

$appPoolPath = ("IIS:\AppPools\" + $applicationPoolName)

Execute-WithRetry { 
    Write-Output "Finding application pool $applicationPoolName"
	$pool = Get-Item $appPoolPath -ErrorAction SilentlyContinue
	if (!$pool) { 
		throw "Application pool $applicationPoolName does not exist" 
	}
}

$sitePath = ("IIS:\Sites\" + $webSiteName)

Write-Output $sitePath

$site = Get-Item $sitePath -ErrorAction SilentlyContinue
if (!$site) { 
	Write-Output "Creating web site $webSiteName"
    Execute-WithRetry {
		$id = (dir iis:\sites | foreach {$_.id} | sort -Descending | select -first 1) + 1
		new-item $sitePath -bindings ($wsBindings[0]) -id $id -physicalPath $webRoot -confirm:$false
    }
} else {
	write-host "Web site $webSiteName already exists"
}

$cmd = { 
	Write-Output "Assigning website to application pool: $applicationPoolName"
	Set-ItemProperty $sitePath -name applicationPool -value $applicationPoolName
}
Execute-WithRetry -Command $cmd

Execute-WithRetry { 
	Write-Output "Setting home directory: $webRoot"
	Set-ItemProperty $sitePath -name physicalPath -value "$webRoot"
}

try {
	Execute-WithRetry { 
		Write-Output "Anonymous authentication enabled: $enableAnonymous"
		Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value "$enableAnonymous" -location $WebSiteName -PSPath "IIS:\"
	}

	Execute-WithRetry { 
		Write-Output "Basic authentication enabled: $enableBasic"
		Set-WebConfigurationProperty -filter /system.webServer/security/authentication/basicAuthentication -name enabled -value "$enableBasic" -location $WebSiteName -PSPath "IIS:\"
	}

	Execute-WithRetry { 
		Write-Output "Windows authentication enabled: $enableWindows"
		Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value "$enableWindows" -location $WebSiteName -PSPath "IIS:\"
	}
} catch [System.Exception] {
	Write-Output "Authentication options could not be set. This can happen when there is a problem with your application's web.config. For example, you might be using a section that requires an extension that is not installed on this web server (such as URL Rewriting). It can also happen when you have selected an authentication option and the appropriate IIS module is not installed (for example, for Windows authentication, you need to enable the Windows Authentication module in IIS/Windows first)"
	throw
}

# It can take a while for the App Pool to come to life
Start-Sleep -s 1

Execute-WithRetry { 
	$state = Get-WebAppPoolState $applicationPoolName
	if ($state.Value -eq "Stopped") {
		Write-Output "Application pool is stopped. Attempting to start..."
		Start-WebAppPool $applicationPoolName
	}
}

if($webSiteStart -eq $true) {
    Execute-WithRetry { 
    	$state = Get-WebsiteState $webSiteName
    	if ($state.Value -eq "Stopped") {
    		Write-Output "Web site is stopped. Attempting to start..."
    		Start-Website $webSiteName
    	}
    }
} else {
	write-host "Not starting Web site $webSiteName"
}

popd

Write-Output "IIS configuration complete"