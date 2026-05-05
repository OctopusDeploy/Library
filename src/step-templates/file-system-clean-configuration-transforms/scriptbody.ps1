# Running outside Octopus Deploy
param(
    [string]$pathToClean,
    [string]$environmentName,
    [switch]$whatIf
)

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

    if ($Required -and [string]::IsNullOrEmpty($result)) {
        throw "Missing parameter value $Name"
    }

    return $result
}

& {
    param(
        [string]$pathToClean,
        [string]$environmentName
    )

    Write-Host "Cleaning Configuration Transform files from $pathToClean and environment: $environmentName"

    if (Test-Path $pathToClean) {
        Write-Host "Scanning directory $pathToClean"
        $regexFilter = "*.$environmentName.config" 
        Write-Host "Filter $regexFilter"

        if ($pathToClean -eq "\" -or $pathToClean -eq "/") {
            throw "Cannot clean root directory"
        }

        $filesToDelete = Get-ChildItem $pathToClean -Filter $regexFilter -Recurse | `
                         Where-Object {!$_.PsIsContainer -and ($_.Name -NotMatch "((?i)(^.*\.exe\.config$|.*\.dll\.config$)$)")}

        if (!$filesToDelete -or $filesToDelete.Count -eq 0) {
            Write-Warning "There were no files matching the criteria"
        } else {

            Write-Host "Deleting files"
            if ($whatIf) {
                Write-Host "What if: Performing the operation `"Remove File`" on targets"
            }

            foreach ($file in $filesToDelete)
            {
                Write-Host "Deleting file $($file.FullName)"
                
                if (!$whatIf) {
                    Remove-Item $file.FullName -Force
                }
            }
        }

    } else {
        Write-Warning "Could not locate path `"$pathToClean`""
    }

} `
(GetParam 'PathToClean' -Required) `
(GetParam 'EnvironmentName' -Required)
