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

function HandleError($message) {
	if (!$whatIf) {
		throw $message
	} else {
		Write-Host $message -Foreground Yellow
	}
}

$appPath = Get-Parameter "ExecutablePath" -Required
$sectionsToEncrypt = (Get-Parameter "SectionsToEncrypt" -Required) -split ',' | where {$_} | %{$_.Trim()}
$provider = Get-Parameter "Provider" "DataProtectionConfigurationProvider"

Write-Host "Configuration - Encrypt .config"
Write-Host "ExecutablePath: $appPath"
Write-Host "SectionToEncrypt: $sectionName"
Write-Host "Provider: $provider"

if (!(Test-Path $appPath)) {
    HandleError "The directory $appPath must exist"
}

$configurationAssembly = "System.Configuration, Version=2.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a"
[void] [Reflection.Assembly]::Load($configurationAssembly)
 
$configuration = [System.Configuration.ConfigurationManager]::OpenExeConfiguration($appPath)

foreach ($sectionToEncrypt in $sectionsToEncrypt){
	$section = $configuration.GetSection($sectionToEncrypt)
 
    if (-not $section.SectionInformation.IsProtected)
    {
        $section.SectionInformation.ProtectSection($provider);
        $section.SectionInformation.ForceSave = [System.Boolean]::True;
    }
}

$configuration.Save([System.Configuration.ConfigurationSaveMode]::Modified);