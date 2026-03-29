## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------

$appPoolName = $OctopusParameters['AppPoolName']

## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------
# Helper for validating input parameters
function Validate-Parameter([string]$foo, [string[]]$validInput, $parameterName) {
    IF (! $parameterName -contains "Password") 
    { 
        Write-Host "${parameterName}: $foo" 
    }
    if (! $foo) {
        throw "No value was set for $parameterName, and it cannot be empty"
    }
}

## --------------------------------------------------------------------------------------
## Configuration
## --------------------------------------------------------------------------------------
Validate-Parameter $appPoolName -parameterName "Application Pool Name"

#Load Web Admin DLL
[System.Reflection.Assembly]::LoadFrom( "C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )

Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue


## --------------------------------------------------------------------------------------
## Run
## --------------------------------------------------------------------------------------

$iis = (New-Object Microsoft.Web.Administration.ServerManager)

$appPool = $iis.ApplicationPools | Where {$_.Name -eq $appPoolName} | Select-Object -First 1

IF ($appPool -eq $null)
{
    Write-Output "Could not find an Application Pool named '$appPoolName'"
}
ELSE
{
    Write-Output "Removing Application Pool '$appPoolName'"
    $iis.ApplicationPools.Remove($appPool)
    $iis.CommitChanges()
}

