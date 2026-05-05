$ErrorActionPreference = "Stop" 
function Get-Parameter($Name, $Default, [switch]$Required) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

function Get-DotNetCoreFrameworkVersions() {
    $dotNetCoreVersions = @()
    if(Test-Path "$env:programfiles/dotnet/shared/Microsoft.NETCore.App") {
        $dotNetCoreVersions = (ls "$env:programfiles/dotnet/shared/Microsoft.NETCore.App").Name
    }
    return $dotNetCoreVersions
}

function Get-AspDotNetCoreRuntimeVersions() {
    $aspDotNetCoreRuntimeVersions = @()
    $DotNETCoreUpdatesPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Updates\.NET Core"
    $DotNETUpdatesPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Updates\.NET"

    if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates\.NET Core") {
	    $DotNetCoreItems = (Get-Item -Path $DotNETCoreUpdatesPath).GetSubKeyNames()
    }
    if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates\.NET") {
        $DotNetItems = (Get-Item -Path $DotNETUpdatesPath).GetSubKeyNames()
    }
	$aspDotNetCoreRuntimeVersions = $DotNetCoreItems + $DotNetItems | where { $_ -match "^Microsoft (ASP)?\.NET Core (?<version>[\d\.]+(.*?)?) "} | foreach { $Matches['version'] }

    return $aspDotNetCoreRuntimeVersions
}

$targetVersion = (Get-Parameter "TargetVersion" -Required).Trim()
$exact = [boolean]::Parse((Get-Parameter "Exact" -Required))
$CheckASPdotNETCore = [boolean]::Parse((Get-Parameter "CheckASPdotNETCore" -Required))

$matchedVersions = Get-DotNetCoreFrameworkVersions | Where-Object { if ($exact) { $_ -eq $targetVersion } else { $_ -ge $targetVersion }  }
if (!$matchedVersions) { 
    throw "Can't find .NET Core Runtime $targetVersion installed in the machine."
}

$matchedVersions | foreach { Write-Host "Found .NET Core Runtime $_ installed in the machine." }

if ($CheckASPdotNETCore) {
    $matchedAspVersions = Get-AspDotNetCoreRuntimeVersions
    if (!$matchedAspVersions) {
        throw "Can't find ASP.NET Core Runtime installed in the machine."
    }

    $matchedAspVersions | foreach { Write-Host "Found ASP.NET Core Runtime $_ installed in the machine." }
}