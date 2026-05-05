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

$websiteDirectory = Get-Parameter "WebsiteDirectory" -Required
$sectionsToEncrypt = (Get-Parameter "SectionsToEncrypt" -Required) -split ',' | where {$_} | %{$_.Trim()}
$provider = Get-Parameter "Provider" ""
$configFile = Get-Parameter "ConfigFile" "web.config"
$otherFiles = (Get-Parameter "OtherFiles" "") -split ',' | where {$_} | %{$_.Trim()}

Write-Host "Configuration - Encrypt .config"
Write-Host "WebsiteDirectory: $websiteDirectory"
Write-Host "SectionsToEncrypt: $sectionsToEncrypt"
Write-Host "Provider: $provider"
Write-Host "ConfigFile: $configFile"


if (!(Test-Path $websiteDirectory)) {
	HandleError "The directory $websiteDirectory must exist"
}

$configFilePath = Join-Path $websiteDirectory $configFile
Write-Host "configFilePath: $configFilePath"
if (!(Test-Path $configFilePath)) {
	HandleError "Specified file $configFile or a Web.Config file must exist in the directory $websiteDirectory"
}

$frameworkPath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory();
$regiis = "$frameworkPath\aspnet_regiis.exe"

if (!(Test-Path $regiis)) {
	HandleError "The tool aspnet_regiis does not exist in the directory $frameworkPath"
}

# Create a temp directory to work out of and copy our config file to web.config
$tempPath = Join-Path $websiteDirectory $([guid]::NewGuid()).ToString()
if (!$whatIf) {
	New-Item $tempPath -ItemType "directory"
} else {
	Write-Host "WhatIf: New-Item $tempPath -ItemType ""directory""" -Foreground Yellow
}

$tempFile = Join-Path $tempPath "web.config"
if (!$whatIf) {
    New-Item -ItemType File -Path $tempFile -Force
	Copy-Item $configFilePath $tempFile -Force
} else {
	Write-Host "WhatIf: Copy-Item $configFilePath $tempFile" -Foreground Yellow
}

Foreach($fileName in $otherFiles){
  if (!$whatIf) {
     New-Item -ItemType File -Path (Join-Path $tempPath $fileName) -Force
	 Copy-Item (Join-Path $websiteDirectory $fileName) (Join-Path $tempPath $fileName) -Force
  } else {
	 Write-Host "WhatIf: Copy-Item $configFilePath $tempFile" -Foreground Yellow
  }
}

Foreach($sectionToEncrypt in $sectionsToEncrypt){
	# Determine arguments
	if ($provider) {
		$args = "-pef", $sectionToEncrypt, $tempPath, "-prov", $provider
	} else {
		$args = "-pef", $sectionToEncrypt, $tempPath
	}

	# Encrypt Web.Config file in directory
	if (!$whatIf) {
		& $regiis $args
		if ($LASTEXITCODE) {
		    HandleError "There was an error trying to encrypt section: $sectionToEncrypt"
		}
	} else {
		Write-Host "WhatIf: $regiis $args" -Foreground Yellow
	}
}

# Copy the web.config back to original file and delete the temp dir
if (!$whatIf) {
	Copy-Item $tempFile $configFilePath -Force

  Foreach($fileName in $otherFiles){
    if (!$whatIf) {
  	 Copy-Item (Join-Path $tempPath $fileName) (Join-Path $websiteDirectory $fileName) -Force
    } else {
  	 Write-Host "WhatIf: Copy-Item $configFilePath $tempFile" -Foreground Yellow
    }
  }

  Remove-Item $tempPath -Recurse
} else {
	Write-Host "WhatIf: Copy-Item $tempFile $configFilePath -Force" -Foreground Yellow
	Write-Host "WhatIf: Remove-Item $tempPath -Recurse" -Foreground Yellow
}
