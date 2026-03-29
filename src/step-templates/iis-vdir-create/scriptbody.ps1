## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------

$virtualPath = $OctopusParameters['VirtualPath'].TrimStart('/',' ').TrimEnd('/', ' ')
$physicalPath = $OctopusParameters['PhysicalPath']
$parentSite = $OctopusParameters['ParentSite']
$application = $OctopusParameters['ApplicationName']
$username = $OctopusParameters['Username']
$password = $OctopusParameters['Password']
$createPhysicalPath = $OctopusParameters['CreatePhysicalPath']

## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------
# Helper for validating input parameters
function Confirm-Parameter([string]$parameterInput, [string[]]$validInput, $parameterName) {
    Write-Host "${parameterName}: $parameterInput"
    if (! $parameterInput) {
        throw "No value was set for $parameterName, and it cannot be empty"
    }

    if ($validInput) {
        if (! $validInput -contains $parameterInput) {
            throw "'$input' is not a valid input for '$parameterName'"
        }
    }

}

# Helper to run a block with a retry if things go wrong
$maxFailures = 5
$sleepBetweenFailures = Get-Random -minimum 1 -maximum 4
function Invoke-CommandWithRetry([ScriptBlock] $command) {
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
Confirm-Parameter $virtualPath -parameterName "Virtual path"
Confirm-Parameter $physicalPath -parameterName "Physical path"
Confirm-Parameter $parentSite -parameterName "Parent site"

if (![string]::IsNullOrEmpty($application)) {
    $application = $application.TrimStart('/',' ').TrimEnd('/',' ')
}

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

$virtualFullPath = $virtualPath

if ($application) {
    Write-Host "Verifying existance of application $application"
    $app = Get-WebApplication -site $parentSite -name $application
    if (!$app) {
        throw "The application '$parentSite' does not exist. Please create the application first."
    } else {
        $virtualFullPath = $application + '/' + $virtualPath
    }
}

# If the physical path down not exist and $createPhysicalPath is true,
# then attempt create it, otherwise throw an error.
if (!(Test-Path $physicalPath)) {
    if ($createPhysicalPath) {
        try {
            Write-Host "Attempting to create physical path '$physicalPath'"
            New-Item -Type Directory -Path $physicalPath -Force
        } catch {
            throw "Couldn't create physical path!"
        }
    } else {
        throw "Physical path does not exist!"
    }
}

# This needs to be improved, especially given applicaltions can be nested.
if ($application) {
    $existing = Get-WebVirtualDirectory -site $parentSite -Application $application -Name $virtualPath
} else {
    $existing = Get-WebVirtualDirectory -site $parentSite -Name $virtualPath
}

Invoke-CommandWithRetry {

    $virtualDirectoryPath = "IIS:\Sites\$parentSite\$virtualFullPath"

    if (!$existing) {
        Write-Host "Creating virtual directory '$virtualPath'"

        New-Item $virtualDirectoryPath -type VirtualDirectory -physicalPath $physicalPath

        Write-Host "Virtual directory created"
    }
    else {
        Write-Host "The virtual directory '$virtualPath' already exists. Checking physical path."

        $currentPath = (Get-ItemProperty $virtualDirectoryPath).physicalPath
        Write-Host "Physical path currently set to $currentPath"

        if ([string]::Compare($currentPath, $physicalPath, $True) -ne 0) {
            Set-ItemProperty $virtualDirectoryPath -name physicalPath -value $physicalPath
            Write-Host "Physical path changed to $physicalPath"
        }
    }

    ## Set vdir pass-through credentails, if applicable
    if (![string]::IsNullOrEmpty($username) -and ![string]::IsNullOrEmpty($password)) {
        Write-Host "Setting Pass-through credentials for username '$username'"

        Set-ItemProperty $virtualDirectoryPath -Name userName -Value $username
        Set-ItemProperty $virtualDirectoryPath -Name password -Value $password

        Write-Host "Pass-through credentials set"
    }
}
