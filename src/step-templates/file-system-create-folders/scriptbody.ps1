# Running outside octopus
param(
    [string]$FolderPaths,
    [string]$ContinueOnError
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

& {
    param(
        [string]$FolderPaths,
        [string]$ContinueOnError
    ) 

    Write-Host "File System - Create Folders"
    Write-Host "FolderPaths: $FolderPaths"
    
    $isContinueOnError = $ContinueOnError.ToLower() -match "(y|yes|true)"

    $FolderPaths.Split(";") | ForEach {
        $path = $_.Trim()

        if($path.Length -lt 1){
            break;
        }

        Write-Host "Trying to ensure directory structure for $path."
        try {
            $newFolder = New-Item -ItemType directory -Path $path -force
            Write-Host "SUCCESS" -ForegroundColor Green
        } catch {
            $errorMessage = "FAILED - $_.Exception.Message"
            
            if($isContinueOnError){
                Write-Host $errorMessage  -ForegroundColor Red
            } else {
                throw $errorMessage
            }
        }
        
    }

 } `
 (Get-Param 'FolderPaths' -Required) `
 (Get-Param 'ContinueOnError')