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

    Write-Host "Restore $webSiteName bindings from bindings variable"

    try {
        Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
        Import-Module WebAdministration -ErrorAction SilentlyContinue
         
        $bindingsBackupFile = Get-File-Name $backupFolder $webSiteName
        $currentBindings = Import-CliXML $bindingsBackupFile 

        if($currentBindings -eq $null) {
            Write-Host "There is no saved bindings, you have to run IIS save bindings before"
        } else {
            foreach($binding in $currentBindings) {
                $bindingArray = $binding.bindingInformation.Split(":")
                $existing = Get-WebBinding -Name $webSiteName -Protocol $binding.protocol | Where-Object { $_.bindingInformation -eq $binding.bindingInformation }

                if($existing -eq $null) {
                    Write-Host "Adding binding" $binding.protocol $binding.bindingInformation                    
                    New-WebBinding -Name $webSiteName -Protocol $binding.protocol -IPAddress $bindingArray[0] -Port $bindingArray[1] -HostHeader $bindingArray[2] -SslFlags $binding.sslFlags
                    if ($binding.protocol -eq "https" -and $binding.certificateHash) {
                        $newBinding = Get-WebBinding -Name $webSiteName -Protocol $binding.protocol -IPAddress $bindingArray[0] -Port $bindingArray[1] -HostHeader $bindingArray[2]
                        Write-Host "Assigning certificate" $binding.certificateHash "to binding"
                        $newBinding.AddSslCertificate($binding.certificateHash, $binding.certificateStoreName)
                    }
                }
            }
        }

        Write-Host "Done"
    } catch {
        Write-Host $_.Exception|format-list -force
        Write-Host "There was a problem restoring bindings"    
    }

 } `
 (Get-Param 'webSiteName' -Required) (Get-Param 'backupFolder' -Required)
