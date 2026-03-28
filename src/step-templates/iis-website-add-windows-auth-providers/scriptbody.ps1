## --------------------------------------------------------------------------------------
## Configuration
## --------------------------------------------------------------------------------------

$isEnabled = $OctopusParameters["add-windows-authentication-providers.is-enabled"]
if (!$isEnabled -or ![boolean]::Parse($isEnabled))
{
   exit 0
}

try {
    Add-PSSnapin WebAdministration
} catch {
    try {
        Import-Module WebAdministration
    } catch {
		Write-Warning "We failed to load the WebAdministration module. This usually resolved by doing one of the following:"
		Write-Warning "1. Install .NET Framework 3.5.1"
		Write-Warning "2. Upgrade to PowerShell 3.0 (or greater)"
        throw ($error | Select-Object -First 1)
    }
}

$webSiteName = $OctopusParameters["add-windows-authentication-providers.website-name"]
$providersString = $OctopusParameters["add-windows-authentication-providers.providers"]
$providers = ($providersString.Split("`r`n,") | % {$_.Trim() } | ? {$_})

## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------
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
## Run
## --------------------------------------------------------------------------------------
Execute-WithRetry { 
    Write-Host "Clearing Windows Authentication Providers for $webSiteName"
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "$webSiteName" -filter system.webServer/security/authentication/windowsAuthentication/providers -name "."
}

$providersPrintedString = $providers -join ", "
Write-Host "Providers to add: $providersPrintedString"
foreach ($provider in $providers) {
    Write-Host "Windows Authentication Provider $provider"
    Execute-WithRetry { 
        Add-WebConfiguration -Filter system.webServer/security/authentication/windowsAuthentication/providers -PSPath IIS:\ -Location "$webSiteName" -Value "$provider"
    }
}