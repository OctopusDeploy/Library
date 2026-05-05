Function Get-Parameter($Name, [switch]$Required, $Default, [switch]$FailOnValidate) {
    $result = $null
    $errMessage = [string]::Empty

    If ($OctopusParameters -ne $null) {
        $octopusParameterName = ("Retention." + $Name)
        $result = $OctopusParameters[$octopusParameterName]
        Write-Host "Octopus paramter value for $octopusParameterName : $result"
    }

    If ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    If ($result -eq $null) {
        If ($Required) {
            $errMessage = "Missing parameter value $Name"
        } Else {
            $result = $Default
        }
    } 

    If (-Not [string]::IsNullOrEmpty($errMessage)) {
        If ($FailOnValidate) {
            Throw $errMessage
        } Else {
            Write-Warning $errMessage
        }
    }

    return $result
}

Function Validate-Parameters([switch]$FailOnValidate) {
    $errMessage = [string]::Empty

    If ($retentionCriteria.ToLower() -eq "days") {
        If ($retentionValue -lt 3) {
            $errMessage = "Retention Value not specified or must be greater than 3 days!"
        }
    } ElseIf ($retentionCriteria.ToLower() -eq "number") {
        If ($retentionValue -lt 10) {
            $errMessage = "Retention Value not specified or must be greater than 9 packages!"
        }
    } Else {
        $errMessage = "Retention Criteria must be 'days' or 'number'!"
    }
    
    If ([string]::IsNullOrEmpty($errMessage)) {
       return $true;
    } Else {
        If ($FailOnValidate) {
            Throw $errMessage
        } Else {
            Write-Warning $errMessage
            return $false;
        }
    }
}

& {
    Write-Host "Start RetentionPolicy"

    $retentionFailOnValidate = [System.Convert]::ToBoolean([string](Get-Parameter "FailOnValidate" $false "False" $false))
    $packagesRootDirectoryPath = [string] (Get-Parameter "PackagesRootDirectory" $true [string]::Empty $retentionFailOnValidate)
    $retentionCriteria = [string] (Get-Parameter "Criteria" $true "days" $retentionFailOnValidate)
    $retentionValue = [int] (Get-Parameter "Value" $true 30 $retentionFailOnValidate)
    $retentionPackageId = [string] (Get-Parameter "PackageId" $true [string]::Empty $retentionFailOnValidate)

    If ((Validate-Parameters $retentionFailOnValidate)) {

        # Filter out package folders by name if parameter specified
        $packageDirectories = Get-ChildItem $packagesRootDirectoryPath | ?{ $_.PSIsContainer } | ?{ $_.Name -eq $retentionPackageId }

        If ($packageDirectories.Length -le 0) {
            Write-Warning "No package directories found!"
        } Else {
            ForEach ($packageDirectory in $packageDirectories) {
                $packageFiles = Get-ChildItem $packageDirectory.FullName
                If ($packageFiles.Length -gt 0) {
                    Write-Host ("Package files found in directory: " + $packageDirectory.FullName + " - " + $packageFiles.Length)
                    $packageFilesObsolete = @()

                    If ($retentionCriteria -eq "days") {
                        $packageFilesObsolete = $packageFiles | ?{ $_.LastWriteTime -le ((Get-Date).AddDays($retentionValue * -1)) }
                    } ElseIf ($retentionCriteria -eq "number") {
                        $filesToDelete = ($packageFiles.Length - $retentionValue)
                        If ($filesToDelete -gt 0) {
                            $packageFilesObsolete = $packageFiles | Sort-Object LastWriteTime | Select-Object -First $filesToDelete
                        }
                    }

                    If ($packageFilesObsolete.Length -gt 0) {
                        Write-Host ("Applying retention policy for " + $packageFilesObsolete.Length + " obsolete files in directory: " + $packageDirectory.FullName)
                        ForEach ($packageVersionFileObsolete in $packageFilesObsolete) {
                            Remove-Item -Path $packageVersionFileObsolete.FullName -Force -Recurse
                        }
                    } Else {
                        Write-Host ("No package files deleted, all files match policy rules!")
                    }
                } Else {
                    Write-Host ("No files found, removing empty directory: " + $packageDirectory.FullName)
                    Remove-Item -Path $packageDirectory.FullName -Force -Recurse
                }
            }
        }
    } ElseIf ($retentionFailOnValidate -eq $true) {
        throw "Missing or invalid parameter values!"
    }

    Write-Host "End RetentionPolicy"
}

