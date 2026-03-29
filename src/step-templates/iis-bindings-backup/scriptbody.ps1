# Running outside octopus
param(
    [string]$webSiteName,
    [string]$backupFolder,
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

    if ($result -eq $null -or $result -eq "") {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

function Get-File-Name($backupFolder, $webSiteName) {
    $folder = Join-Path -Path $backupFolder -ChildPath $webSiteName

    if((Test-Path $folder) -eq $false) {
        mkdir $folder | Out-Null
    }

    $fullPath = $null;

    if($OctopusParameters -eq $null) {
         $fullPath = Join-Path -Path $folder -ChildPath "site_backup.xml"
    } else {
         $fileName = $OctopusParameters["Octopus.Release.Number"] + "_" + $OctopusParameters["Octopus.Environment.Name"] + ".xml"
         $fullPath = Join-Path -Path $folder -ChildPath $fileName
    }

    return $fullPath
}

& {
    param(
        [string]$webSiteName,
        [string]$backupFolder
    ) 

    Write-Host "Save $webSiteName bindings to bindings variable"

    try {
         Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
         Import-Module WebAdministration -ErrorAction SilentlyContinue

         $currentBindings = Get-WebBinding -Name $webSiteName
         $bindingsBackupFile = Get-File-Name $backupFolder $webSiteName
         $currentBindings | Export-CliXML $bindingsBackupFile

         Write-Host "Done"
    } catch {
        Write-Host $_.Exception|format-list -force
        Write-Host "There was a problem saving bindings"    
    }

 } `
 (Get-Param 'webSiteName' -Required) (Get-Param 'backupFolder' -Required)
