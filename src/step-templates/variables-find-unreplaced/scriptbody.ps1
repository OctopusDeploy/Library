function Find-Unreplaced {
    <#
    .SYNOPSIS
        Looks for Octopus Deploy variables
    .DESCRIPTION
        Analyses `Web/App.Release.configs`, etc... looking for Octopus Deploy 
        variables that have not been replaced.
    .EXAMPLE
        Find-Unreplaced C:\Folder *.config, *.ps1 
    .PARAMETER Path
        Root folder to search in
    .PARAMETER Files
        An array of all the files or globs to search in. Defaults to *.config
    .PARAMETER Exclude
        Files to ignore
    .PARAMETER Recurse
        Should the cmdlet look for the file types recursively
    .PARAMETER TreatAsError
        Will cause the script to write an Error instead of a warning if variables are found
    #>
    [CmdletBinding()]
    param 
    (
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$True)]
        [string] $Path,
        
        [Parameter(
            Position=1,
            Mandatory=$false)]
        [string[]] $Files = @('*.config'),
        
        [Parameter(Mandatory=$false)]
        [string[]] $Exclude,
        
        [Parameter(Mandatory=$false)]
        [switch] $Recurse,
        
        [Parameter(Mandatory=$false)]
        [switch] $TreatAsError
    )

    process {
        Write-Host "Searching for files in '$Path'"
        if (-not (Test-Path $Path -PathType container)) {
            Write-Error "The path '$Path' does not exist or is not a folder."
            return
        }
        
        if (-not $Recurse) {
            # For some reason, a splat is required when not recursing
            if ($Path.EndsWith("\")) { $Path += "*" } else { $Path += "\*" }
        }

        $clean = $true

        $found = Get-ChildItem -Path $Path -Recurse:$Recurse -Include $Files -Exclude $Exclude -File
        foreach ($file in $found) {
            Write-Host "Found '$file'.`nSearching for Octopus variables..." -NoNewline
            $matches = Select-String -Path $file -Pattern "#\{([^}]*)\}" -AllMatches
            $clean = $clean -and ($matches.Count -eq 0)
            if ($clean) {
                Write-Host "clean"
            } else {
                Write-Host "done`n$matches"
            }
        }

        if (-not $clean) {
            $msg = "Unreplaced Octopus Variables were found."
            if ($TreatAsError) {
                Write-Error $msg
            } else {
                Write-Warning $msg
            }
        }
    }
}

if (-not $Path) { throw "A Path must be specified" }
if (-not $Files) { throw "At least one File must be specified" }

$spPaths = $Path -split "`n" | Foreach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) }
$spFiles = $Files -split ";" | Foreach-Object { $_.Trim() } 
$spExcludes = $Exclude -split ";" | Foreach-Object { $_.Trim() } 
$bRecurse = $Recurse -eq 'True'
$bTreatAsError = $TreatAsError -eq 'True'

$spPaths | Find-Unreplaced -Files $spFiles -Exclude $spExcludes -Recurse:$bRecurse -TreatAsError:$bTreatAsError

