$ErrorActionPreference = "Stop";
function Get-Exceptions {
    param ($ExceptionObject)
    
    if ($null -ne $ExceptionObject.InnerException) {
        Get-Exceptions -ExceptionObject $ExceptionObject.InnerException
    }
    
    Write-Warning "Exception is: $($ExceptionObject.Message)"
}

function Resolve-OctopusVariablesInTemplate {
    <#
.SYNOPSIS
	Resolves Octopus variables in files with their values from a OctopusParameters

.DESCRIPTION
	Looks for files using Get-ChildItem and in each of the files replaces ${Variable} with the value from $OctopusParameters.
	Files are written back using UTF-8.
	Requires PowerShell 3.0 or higher.

.PARAMETER Path
	Passed to Get-ChildItem to find the files you want to process

.PARAMETER Filter
	Passed to Get-ChildItem to find the files you want to process

.PARAMETER Include
	Passed to Get-ChildItem to find the files you want to process

.PARAMETER Exclude
	Passed to Get-ChildItem to find the files you want to process
	
.PARAMETER Recurse
	Passed to Get-ChildItem to find the files you want to process

#>
    Param(
        [string]$Path,
        [string]$Filter = "*.config",
        [string[]]$Include,
        [string[]]$Exclude,
        [switch]$Recurse,
        [string]$OctostacheLocation
    )
	
    if (-not $OctopusParameters) { throw "No OctopusParameters found" }
	
    Write-Output "Tentacle Version: $env:TentacleVersion"
    Write-Output "PowerShell version..."
    Write-Output $PSVersionTable
    Write-Output "Path = $Path"
	
    Write-Output "Getting target files..."
    $TargetFiles = Get-ChildItem -File -Path $Path -Filter $Filter -Include $Include -Exclude $Exclude -Recurse:$Recurse
    if ($TargetFiles.Count -eq 0) {
        Write-Warning "`tDid not find any files to process!"
        return
    }
    else {
        Write-Output "`tFound $($TargetFiles.Count) file(s)"
    }
	
    Import-Octostache -OctostacheLocation $OctostacheLocation

    foreach ($File in $TargetFiles) {
        Resolve-VariablesUsingOctostache $File.FullName
    }        
}


function Import-Octostache {
    Param(
        [string]$OctostacheLocation
    )
    
    $OctostachePath = $null
    $SprachePath = $null
    
    Write-Output "Searching for installed version of Octostache."
    if (-not [string]::IsNullOrWhiteSpace($OctostacheLocation)) {
        if (-not (Test-Path $OctostacheLocation)) {
            Write-Error "Octostache path: $OctostacheLocation doesnt exist."
            Exit 1
        }
        Write-Verbose "Searching in $OctostacheLocation for Octostache.dll"
        $OctostacheLibraryLocations = Get-ChildItem -File -Path $OctostacheLocation -Filter "OctoStache.dll" -Recurse
        $OctostachePath = ($OctostacheLibraryLocations | Select-Object -First 1).FullName
        Write-Verbose "Searching in $OctostacheLocation for Sprache.dll"
        $SpracheLibraryLocations = Get-ChildItem -File -Path $OctostacheLocation -Filter "Sprache.dll" -Recurse
        $SprachePath = ($SpracheLibraryLocations | Select-Object -First 1).FullName
    }
    else {
        try {
            $OctostachePackage = (Get-Package Octostache -ErrorAction Stop) | Select-Object -First 1
        } 
        catch {
            $OctostachePackage = $null
        }

        if ($null -eq $OctostachePackage) {
            Write-Output "Downloading Octostache (v3.2.1) from nuget.org."
            Install-Package Octostache -MaximumVersion "3.2.1" -source https://www.nuget.org/api/v2 -Force -SkipDependencies
            $OctostachePackage = (Get-Package Octostache) | Select-Object -First 1
        }
    
        $OctostachePath = Join-Path (Get-Item $OctostachePackage.source).Directory.FullName "lib/net40/Octostache.dll"

        try {
            $SprachePackage = (Get-Package Sprache -ErrorAction Stop) | Select-Object -First 1
        } 
        catch {
            $SprachePackage = $null
        }

        if ($null -eq $SprachePackage) {
            Write-Output "Downloading Sprache (v2.3.1) from nuget.org."
            Install-Package Sprache -MaximumVersion "2.3.1" -source https://www.nuget.org/api/v2 -Force -SkipDependencies
            $SprachePackage = @(Get-Package Sprache) | Select-Object -First 1
        }

        $SprachePath = Join-Path (Get-Item $SprachePackage.source).Directory.FullName "lib/net40/Sprache.dll"
    }

    Write-Verbose "Octostache path: $OctostachePath"
    Write-Verbose "Sprache path: $SprachePath"

    if ([string]::IsNullOrWhiteSpace($OctostachePath) -or [string]::IsNullOrWhiteSpace($SprachePath)) {
        Write-Error "Couldnt locate either the Octostache or Sprache library."
        Exit 1
    }

    Write-Output "Adding type $SprachePath"
    Add-Type -Path $SprachePath

    Write-Output "Adding type $OctostachePath"
    Add-Type -Path $OctostachePath
}

function Resolve-VariablesUsingOctostache {
    Param(
        [string]$TemplateFile
    )
		
    Write-Output "Loading template file $TemplateFile..."
    $TemplateContent = Get-Content -Raw $TemplateFile
    Write-Output "`tRead $($TemplateContent.Length) bytes"
	
    $Dictionary = New-Object -TypeName Octostache.VariableDictionary
	
    # Load the hastable into the dictionary
    Write-Output "Loading `$OctopusParameters..."
    foreach ($Variable in $OctopusParameters.GetEnumerator()) {
        Write-Verbose "#{$($Variable.Key)} = $($Variable.Value)"
        $Dictionary.Set($Variable.Key, $Variable.Value)
    }
	
    Write-Output "Resolving variables..."
    
    try {
        $EvaluatedTemplate = $Dictionary.Evaluate($TemplateContent)
    }
    catch {
        Get-Exceptions -ExceptionObject $Error.Exception
        throw
    }
	
    Write-Output "Writing the resolved template to $($TemplateFile) (UTF8 encoding)"
    #$EvaluatedTemplate | Out-File $TemplateFile -Force	-Encoding UTF8
    $EvaluatedTemplate -join "rn" | Set-Content $TemplateFile -NoNewLine -Encoding UTF8 -Force
    Write-Output "Done!"
}

$FunctionParameters = @{}

if ($null -ne $OctopusParameters['Path']) { $FunctionParameters.Add('Path', $OctopusParameters['Path']) }
if ($null -ne $OctopusParameters['Filter']) { $FunctionParameters.Add('Filter', $OctopusParameters['Filter']) }
if ($null -ne $OctopusParameters['Include']) { $FunctionParameters.Add('Include', $($OctopusParameters['Include'] -split "`n")) }
if ($null -ne $OctopusParameters['Exclude']) { $FunctionParameters.Add('Exclude', $($OctopusParameters['Exclude'] -split "`n")) }
if ($null -ne $OctopusParameters['Recurse']) { $FunctionParameters.Add('Recurse', [System.Convert]::ToBoolean($OctopusParameters['Recurse'])) }
if (-not [string]::IsNullOrWhiteSpace($OctopusParameters['Variables.SubstituteInFiles.OctostacheLocation'])) { $FunctionParameters.Add('OctostacheLocation', $OctopusParameters['Variables.SubstituteInFiles.OctostacheLocation']) }

Resolve-OctopusVariablesInTemplate @FunctionParameters