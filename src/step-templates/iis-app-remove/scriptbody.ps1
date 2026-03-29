## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------

$virtualPath = $OctopusParameters['VirtualPath']
$parentSite = $OctopusParameters['ParentSite']

## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------
# Helper for validating input parameters
function Validate-Parameter([string]$foo, [string[]]$validInput, $parameterName) {
    Write-Host "${parameterName}: $foo"
    if (! $foo) {
        throw "No value was set for $parameterName, and it cannot be empty"
    }
    
    if ($validInput) {
        if (! $validInput -contains $foo) {
            throw "'$input' is not a valid input for '$parameterName'"
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
Validate-Parameter $parentSite -parameterName "Parent site"

Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue

## --------------------------------------------------------------------------------------
## Run
## --------------------------------------------------------------------------------------

Write-Host "Getting web site $parentSite"
$site = Get-Website -name $parentSite
if (!$site) {
    throw "The web site '$parentSite' does not exist. Please create the site first."
}

$parts = $virtualPath -split "[/\\]"
$name = ""

for ($i = 0; $i -lt $parts.Length; $i++) {
    $name = $name + "/" + $parts[$i]
    $name = $name.TrimStart('/').TrimEnd('/')
    if ($i -eq $parts.Length - 1) {
        
    }
    elseif ([string]::IsNullOrEmpty($name) -eq $false -and $name -ne "/") {
        Write-Host "Ensuring parent exists: $name"

        $app = Get-WebApplication -Name $name -Site $parentSite

        if (!$app) {
            $vdir = Get-WebVirtualDirectory -Name $name -site $parentSite
            if (!$vdir) {
                throw "The application or virtual directory '$name' does not exist"
            }
        }
    }
}

$existing = Get-WebApplication -site $parentSite -Name $name

Execute-WithRetry { 
    if ($existing) {
        Write-Host "Removing web application '$name'"
		Remove-WebApplication -Name $name -Site $parentSite
        Write-Host "Web application removed"
    } else {
        Write-Host "Web application doesn't exist, nothing to remove."
    }
}