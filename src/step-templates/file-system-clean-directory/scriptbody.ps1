# Running outside octopus
param(
	[string]$cleanInclude,
	[string]$cleanIgnore,
	[string]$pathsToClean,
	[switch]$whatIf
) 

function ExpandPathExpressions($workingDirectory, $fileExpressionList) {
	return @($fileExpressionList.Split(@(";"), "RemoveEmptyEntries")) | 
	% { $_.Trim() } |
	% { ExpandPathExpression $workingDirectory $_ }
}

function ExpandPathExpression($workingDirectory, $FileExpression) {

	# \**\ denotes a recursive search
	$recurse = "**"

	# Scope the clean!
	$fileExpression = Join-Path $workingDirectory $fileExpression

	$headSegments = Split-Path $fileExpression
	$lastSegment = Split-Path $fileExpression -Leaf
	$secondLastSegment = $(if($headSegments -ne "") {Split-Path $headSegments -Leaf} else {$null}) 

	$path = "\"
	$recursive = $false
	$filter = "*"
	
	if ($lastSegment -eq $recurse) {	
	
		$path = $headSegments
		$recursive = $true
		
	} elseif ($secondLastSegment -eq $recurse) {
		
		$path = Split-Path $headSegments
		$recursive = $true
		$filter = $lastSegment	
	
	} else {
		
		$path = $headSegments
		$filter = $lastSegment 
	}

	return Get-ChildItem -Path $path -Filter $filter -Recurse:$recursive | ? { !$_.PSIsContainer }
}

function GetParam($Name, [switch]$Required) {
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
	
	if ($Required -and $result -eq $null) {
		throw "Missing parameter value $Name"
	}
	
	return $result
}

& {
	param(
		[string]$cleanInclude,
		[string]$cleanIgnore,
		[string]$pathsToClean
	) 

	Write-Host "Cleaning files from installation directory"
	Write-Host "Include: $cleanInclude"
	Write-Host "Ignore: $cleanIgnore"
	Write-Host "Paths To Clean: $pathsToClean"
	
	if (!$cleanInclude) {
		throw "You must specify files to include"
	}
	
	if (!$pathsToClean) {
		throw "You must specify the paths to clean"
	}
	
	$paths = @($pathsToClean.Split(@(";"), "RemoveEmptyEntries")) | 
	% { $_.Trim() }
	
	foreach ($pathToClean in $paths) {
		
		if (Test-Path $pathToClean) {
			Write-Host "Scanning directory $pathToClean"
			
			if ($pathToClean -eq "\" -or $pathToClean -eq "/") {
				throw "Cannot clean root directory"
			}
			
			cd $pathToClean
			
			$include = ExpandPathExpressions $pathToClean $cleanInclude
			$exclude = ExpandPathExpressions $pathToClean $cleanIgnore
			
			if ($include -eq $null -or $exclude -eq $null) {
				$deleteSet = $include
			} else {
				$exclude = $exclude | % {$_}
				$deleteSet = Compare-Object $include $exclude | ? { $_.SideIndicator -eq "<=" } | % { $_.InputObject }
			}
			
			if (!$deleteSet -or $deleteSet.Count -eq 0) {
				Write-Warning "There were no files matching the criteria"
			} else {
				
				Write-Host "Deleting files"
				if ($whatIf) {
					Write-Host "What if: Performing the operation `"Remove File`" on targets"
				}
				
				$deleteSet | Write-Host
				
				if (!$whatIf) {
					$deleteSet | % { $_.FullName } | Remove-Item -Force -Recurse -WhatIf:$whatIf
				}
			}
		
		} else {
			
			Write-Warning "Could not locate path `"$pathToClean`""
		}
	}
 } `
 (GetParam 'CleanInclude' -Required) `
 (GetParam 'CleanIgnore') `
 (GetParam 'PathsToClean')
 