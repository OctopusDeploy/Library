## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------

$virtualPath = $OctopusParameters['VirtualPath']
$physicalPath = $OctopusParameters['PhysicalPath']
$applicationPoolName = $OctopusParameters['ApplicationPoolName']
$setApplicationPoolSettings = [boolean]::Parse($OctopusParameters['SetApplicationPoolSettings'])
$appPoolFrameworkVersion = $OctopusParameters["ApplicationPoolFrameworkVersion"]
$applicationPoolIdentityType = $OctopusParameters["ApplicationPoolIdentityType"]
$applicationPoolUsername = $OctopusParameters["ApplicationPoolUsername"]
$applicationPoolPassword = $OctopusParameters["ApplicationPoolPassword"]

$parentSite = $OctopusParameters['ParentSite']
$bindingProtocols = $OctopusParameters['BindingProtocols']
$authentication = $OctopusParameters['AuthenticationType']
$requireSSL = $OctopusParameters['RequireSSL']
$clientCertificate = $OctopusParameters['ClientCertificate']

$preloadEnabled = [boolean]::Parse($OctopusParameters['PreloadEnabled'])
$enableAnonymous = [boolean]::Parse($OctopusParameters['EnableAnonymous'])
$enableBasic = [boolean]::Parse($OctopusParameters['EnableBasic'])
$enableWindows = [boolean]::Parse($OctopusParameters['EnableWindows'])

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
## Configuration
## --------------------------------------------------------------------------------------
Validate-Parameter $virtualPath -parameterName "Virtual path"
Validate-Parameter $physicalPath -parameterName "Physical path"
Validate-Parameter $applicationPoolName -parameterName "Application pool"
Validate-Parameter $parentSite -parameterName "Parent site"


Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue


## --------------------------------------------------------------------------------------
## Run
## --------------------------------------------------------------------------------------

Write-Host "Getting web site $parentSite"
# Workaround to bug in Get-WebSite cmdlet which would return all sites
# See http://forums.iis.net/p/1167298/1943273.aspx / http://stackoverflow.com/a/6832577/785750
$site = Get-WebSite  | where { $_.Name -eq $parentSite }
if (!$site) {
    throw "The web site '$parentSite' does not exist. Please create the site first."
}

$path = $site.PhysicalPath;
$parts = $virtualPath -split "[/\\]"
$name = ""

for ($i = 0; $i -lt $parts.Length; $i++) {
    $name = $name + "/" + $parts[$i]
    $name = $name.TrimStart('/').TrimEnd('/')
    if ($i -eq $parts.Length - 1) {
        
    }
    elseif ([string]::IsNullOrEmpty($name) -eq $false -and $name -ne "") {
        Write-Host "Ensuring parent exists: $name"
        
        $path = [IO.Path]::Combine($path, $parts[$i])
        $app = Get-WebApplication -Name $name -Site $parentSite

        if (!$app) {
            $vdir = Get-WebVirtualDirectory -Name $name -site $parentSite
            if (!$vdir) {
                Write-Verbose "The application or virtual directory '$name' does not exist"
                if([IO.Directory]::Exists([System.Environment]::ExpandEnvironmentVariables($path)) -eq $true)
                {
                    Write-Verbose "Using physical path '$path' as parent"
                }
                else
                {
                    throw "Failed to ensure parent"
                }
            }
            else
            {
                $path = $vdir.PhysicalPath
            }
        }
        else
        {
            $path = $app.PhysicalPath
        }
    }
}

$existing = Get-WebApplication -site $parentSite -Name $name

# Set App Pool
Execute-WithRetry { 
	Write-Verbose "Loading Application pool"
	$pool = Get-Item "IIS:\AppPools\$ApplicationPoolName" -ErrorAction SilentlyContinue
	if (!$pool) { 
		Write-Host "Application pool `"$ApplicationPoolName`" does not exist, creating..." 
		new-item "IIS:\AppPools\$ApplicationPoolName" -confirm:$false
		$pool = Get-Item "IIS:\AppPools\$ApplicationPoolName"
	} else {
		Write-Host "Application pool `"$ApplicationPoolName`" already exists"
	}
}

# Set App Pool Identity
Execute-WithRetry { 
	if($setApplicationPoolSettings)
    {
        Write-Host "Set application pool identity: $applicationPoolIdentityType"
        if ($applicationPoolIdentityType -eq "SpecificUser") {
            Set-ItemProperty "IIS:\AppPools\$ApplicationPoolName" -name processModel -value @{identitytype="SpecificUser"; username="$applicationPoolUsername"; password="$applicationPoolPassword"}
        } else {
            Set-ItemProperty "IIS:\AppPools\$ApplicationPoolName" -name processModel -value @{identitytype="$applicationPoolIdentityType"}
        }
    }
}

# Set .NET Framework
Execute-WithRetry { 
    if($setApplicationPoolSettings)
    {
        Write-Host "Set .NET framework version: $appPoolFrameworkVersion" 
        if($appPoolFrameworkVersion -eq "No Managed Code")
        {
            Set-ItemProperty "IIS:\AppPools\$ApplicationPoolName" managedRuntimeVersion ""
        }
        else
        {
            Set-ItemProperty "IIS:\AppPools\$ApplicationPoolName" managedRuntimeVersion $appPoolFrameworkVersion
        }
    }
}

Execute-WithRetry { 
    ## Check if the physical path exits
    if(!(Test-Path -Path $physicalPath)) {
        Write-Host "Creating physical path '$physicalPath'"
        New-Item -ItemType directory -Path $physicalPath
    }

    if (!$existing) {
        Write-Host "Creating web application '$name'"
        New-WebApplication -Site $parentSite -Name $name -ApplicationPool $applicationPoolName -PhysicalPath $physicalPath
        Write-Host "Web application created"
    } else {
        Write-Host "The web application '$name' already exists. Updating physical path:"

        Set-ItemProperty IIS:\\Sites\\$parentSite\\$name -name physicalPath -value $physicalPath
        Write-Host "Physical path changed to: $physicalPath"

        Set-ItemProperty IIS:\\Sites\\$parentSite\\$name -Name applicationPool -Value $applicationPoolName
        Write-Output "ApplicationPool changed to: $applicationPoolName"
    }
    
    Write-Host "Enabling '$bindingProtocols' protocols"
    Set-ItemProperty IIS:\\Sites\\$parentSite\\$name -name enabledProtocols -value $bindingProtocols

    $enabledIisAuthenticationOptions = $Authentication -split '\\s*[,;]\\s*'

    try {

    Execute-WithRetry { 
        Write-Output "Anonymous authentication enabled: $enableAnonymous"
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value "$enableAnonymous" -PSPath IIS:\\ -location $parentSite/$virtualPath
    }    
    
    Execute-WithRetry { 
        Write-Output "Windows authentication enabled: $enableWindows"
        Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/windowsAuthentication -name enabled -value "$enableWindows" -PSPath IIS:\\ -location $parentSite/$virtualPath
    }

    Execute-WithRetry { 
        Write-Output "Basic authentication enabled: $enableBasic"
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/basicAuthentication -name enabled -value "$enableBasic" -PSPath IIS:\\ -location $parentSite/$virtualPath
    }

    } catch [System.Exception] {
        Write-Output "Authentication options could not be set. This can happen when there is a problem with your application's web.config. For example, you might be using a section that requires an extension that is not installed on this web server (such as URL Rewriting). It can also happen when you have selected an authentication option and the appropriate IIS module is not installed (for example, for Windows authentication, you need to enable the Windows Authentication module in IIS/Windows first)"
        throw
    }

    Set-WebConfiguration -value "None" -filter "system.webserver/security/access" -location $parentSite/$virtualPath -PSPath IIS:\\ 
    if ($requireSSL -ieq "True")
    {
        Write-Output "Require SSL enabled: $requireSSL"
        Set-WebConfiguration -value "Ssl" -filter "system.webserver/security/access" -location $parentSite/$virtualPath -PSPath IIS:\\ 
        Write-Output "Client certificate mode: $clientCertificate"
        if ($clientCertificate -ieq "Accept") {
           Set-WebConfigurationProperty -filter "system.webServer/security/access" -location $parentSite/$virtualPath -PSPath IIS:\\ -name "sslFlags" -value "Ssl,SslNegotiateCert"
        }
        if ($clientCertificate -ieq "Require") {
           Set-WebConfigurationProperty -filter "system.webServer/security/access" -location $parentSite/$virtualPath -PSPath IIS:\\ -name "sslFlags" -value "Ssl,SslNegotiateCert,SslRequireCert"
        }
    }
    
    try {
        Set-ItemProperty IIS:\\Sites\\$parentSite\\$name -name preloadEnabled -value $preloadEnabled
        Write-Output "Preload Enabled: $preloadEnabled"
    } catch [System.Exception] {
       if ($preloadEnabled) {
            Write-Output "Preload Enabled: $preloadEnabled Could not be set. You may to install the Application Initialization feature"
            throw
       }
    }
}
