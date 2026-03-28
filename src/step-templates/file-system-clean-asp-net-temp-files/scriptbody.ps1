# Running outside octopus
param(
	[string]$frameworkVersion,
	[int]$daysToKeep,
	[switch]$whatIf
) 

$ErrorActionPreference = "Stop"

function Get-Param($Name, [switch]$Required, $Default) {
	$result = $null
	
	if ($OctopusParameters -ne $null) {
		$result = $OctopusParameters[$Name]
	}

	if ($result -eq $null) {
		$variable = Get-Variable $Name -EA SilentlyContinue	
		if ($variable -ne $null) {
			$result = $variable.Value
		}
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

function RemoveSafely-Item($folder, $Old, [switch]$whatIf) {
	
	if ($folder.LastWriteTime -lt $old) {
		
		try {
			Write-Host "Removing: $($folder.FullName)"
			$folder | Remove-Item -Recurse -Force -WhatIf:$whatIf -EA Stop
		} catch {
			$message = $_.Exception.Message
			Write-Host "Info: Could not remove $itemName. $message"
		}
	}
}

& {
	param(
		[string]$frameworkVersion,
		[int]$daysToKeep
	) 

	Write-Host "Cleaning Temporary ASP.NET files directory"
	
	if ([string]::IsNullOrEmpty($frameworkVersion)) {
		throw "You need to specify the frameworkVersion parameter"
	}
	
	Write-Host "FrameworkVersion: $frameworkVersion"
	
	$dotnetPath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory() | Split-Path | Split-Path
	$bitnessValues = @("Framework", "Framework64")
	$versionStart = "v"
	$versionFilter = "$versionStart"
	$tempDir = "Temporary ASP.NET Files"
	
	$directoriesToClean = @()
	
	if ($frameworkVersion -ne "All") {
	
		# Starts with v
		if ($frameworkVersion.StartsWith($versionStart, "CurrentCultureIgnoreCase")) {
			$versionFilter = $frameworkVersion
			if ($frameworkVersion -contains "\") {
				throw "Framework version cannot contain '\'"
			}
		} else {
		
			# Includes one \
			$firstSlash = $frameworkVersion.IndexOf("\")
			
			$NotAVersion = -1
			if ($firstSlash -eq $NotAVersion) {
				$bitnessValues = @($frameworkVersion)
			} else {
			
				$secondSlash = $frameworkVersion.IndexOf("\", $firstSlash)
				
				$NoExtraSlash = -1
				if ($secondSlash -ne $NoExtraSlash) {
					
					$bitnessValues = @($frameworkVersion | Split-Path)
					$versionFilter = @($frameworkVersion | Split-Path -Leaf)

				} else {
					throw "Includes more than one '\'"
				}
			}
		}
	}
	
	if (!$versionFilter.StartsWith($versionStart, "CurrentCultureIgnoreCase")) {
		throw "Version filter must start with '$versionStart'"
	}
	
	foreach ($bitness in $bitnessValues) {
		$fvPath = (Join-Path $dotnetPath $bitness)
		if (Test-Path $fvPath) {
			$directoriesToClean += (ls $fvPath -Filter "$versionFilter*")
		}
	}
	
	foreach ($dir in $directoriesToClean) {
		$fullTempPath = Join-Path $dir.FullName $tempDir
		
		if (Test-Path $fullTempPath) {
			$virtualDirectories = ls $fullTempPath
			foreach ($virtualPathDir in $virtualDirectories) {
				$old = (Get-Date).AddDays(-$daysToKeep)
				
				foreach ($siteDir in (Get-ChildItem $virtualPathDir.FullName)) {
					RemoveSafely-Item $siteDir $old -WhatIf:$whatIf
				}
			}
		}
	}
	
 } `
 (Get-Param 'frameworkVersion' -Required) `
 (Get-Param 'daysToKeep' -Default 30) 
 