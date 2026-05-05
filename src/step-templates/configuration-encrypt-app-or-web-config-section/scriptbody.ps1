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

    Write-Verbose "Get-Parameter for '$($Name)' [value='$($result)' default='$($Default)']"

    return $result
}

function HandleError($message) {
	if (!$whatIf) {
		throw $message
	} else {
		Write-Host $message -Foreground Yellow
	}
}

function Invoke-EncryptAppConfigFile() {

    if (!(Test-Path $appPath)) {
        HandleError "The directory $appPath must exist"
    }

    $configurationAssembly = "System.Configuration, Version=2.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a"
    [void] [Reflection.Assembly]::Load($configurationAssembly)
    $configuration = [System.Configuration.ConfigurationManager]::OpenExeConfiguration($appPath)

    Invoke-ProtectSections $configuration
}

function Invoke-EncryptWebConfigFile() {
    Import-module WebAdministration

	$IISPath = "IIS:\Sites\$($webSiteName)$($appPath)\"

    if (Test-Path $IISPath) { 
        Write-Verbose "$webSiteName web site exists."

        $configurationAssembly = "System.Web, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"
        [void] [Reflection.Assembly]::Load($configurationAssembly)
        $configuration = [System.Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($appPath, $webSiteName)

        Invoke-ProtectSections $configuration
    }
    else {
        HandleError "$webSiteName web site doesn't exists. Please check if the web site is installed."
    }    
}

function Invoke-ProtectSections($configuration) {

    $saveConfigFile = $false

    foreach ($sectionName in $sections) {
        $sectionName = $sectionName.Trim()      # compatible with Powershell 2.0 
        $section = $configuration.GetSection($sectionName)
        
        if ($section) {
            if (-not $section.SectionInformation.IsProtected)
            {
                Write-Verbose "Encrypting $($section.SectionInformation.SectionName) section."
                $section.SectionInformation.ProtectSection($provider);
                $section.SectionInformation.ForceSave = [System.Boolean]::True;
                $saveConfigFile = $true
            }
            else {
                Write-Host "Section $($section.SectionInformation.SectionName) is already protected."
            }
        }
        else {
            Write-Warning "Section $($sectionName) doesn't exists in the configuratoin file."
        }

    }       

    if ($saveConfigFile) {            
        $configuration.Save([System.Configuration.ConfigurationSaveMode]::Modified);
        Write-Host "Encryption completed successfully."
    }
    else {
        Write-Host "No section(s) in the configuration were encrypted."
    }
}

$appType = Get-Parameter "ApplicationType" -Required
if ($appType -eq "Web") {
    $appPath = Get-Parameter "ExecutablePath" "/"
    $webSiteName = Get-Parameter "WebSiteName"
}
else {
    $appPath = Get-Parameter "ExecutablePath" -Required
}
$sectionName = Get-Parameter "SectionToEncrypt" -Required
$sections = $sectionName.Split(',')         # adding .Trim() doesn't work on Powershell 2.0 or below
$provider = Get-Parameter "Provider" "DataProtectionConfigurationProvider"

Write-Host "Configuration - Encrypt config file"
Write-Host "Application Type: $appType"
Write-Host "Application Path: $appPath"
if ($appType -eq "Web") { Write-Host "Web Site Name: $webSiteName" }
Write-Host "Section to Encrypt: $sectionName"
Write-Host "Provider: $provider"

if ($appType -eq "Web") {
    Invoke-EncryptWebConfigFile
}
else {
    Invoke-EncryptAppConfigFile 
}