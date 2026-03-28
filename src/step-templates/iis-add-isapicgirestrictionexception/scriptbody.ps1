Param
(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $cgiIsapiExtensionPath,
    [Parameter(Position = 1)]
    [string] $description = [string]::Empty
)

$ErrorActionPrefrence = "Stop"


function Get-Param($Name, [switch]$Required, $Default) 
{
    $result = $null

    if ($OctopusParameters -ne $null) 
    {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) 
    {
        $variable = Get-Variable $Name -EA SilentlyContinue    
        if ($variable -ne $null) 
        {
            $result = $variable.Value
        }
    }

    if ($result -eq $null) 
    {
        if ($Required) 
        {
            throw "Missing parameter value $Name"
        } 
        else 
        {
            $result = $Default
        }
    }

    return $result
}

& {
    Param
    (
        [Parameter(Mandatory=$True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $cgiIsapiExtensionPath,
        [Parameter(Position = 1)]
        [string] $description = [string]::Empty
    )

    Import-Module "WebAdministration"

    $cgiIsapiConfiguration = Get-WebConfiguration -Filter "/system.webServer/security/isapiCgiRestriction/add" -PSPath "IIS:\"

    $cgiIsapiExtensionFullPath = [System.Environment]::ExpandEnvironmentVariables($cgiIsapiExtensionPath)
    $cgiIsapiExtensionFullPath = Resolve-Path -Path $cgiIsapiExtensionFullPath

    $restrictionFound = $false
    $cgiIsapiConfiguration | ForEach-Object {
        $itemFullPath = [System.Environment]::ExpandEnvironmentVariables($_.path)
        $itemFullPath = Resolve-Path -Path $itemFullPath

        if ($itemFullPath.Path -eq $cgiIsapiExtensionFullPath.Path)
        {
           $restrictionFound = $true
        }
    }

    if ($restrictionFound -eq $false)
    {
        Add-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/isapiCgiRestriction" -value @{description="$description";path="$cgiIsapiExtensionPath";allowed='True'}
    }
    else
    {
        Write-Host "Allowed CGI/ISAPI Restriction for '$cgiIsapiExtensionPath' already exists."
    }
} `
(Get-Param 'cgiIsapiExtensionPath' -Required) `
(Get-Param 'description')