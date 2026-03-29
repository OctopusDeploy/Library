# Running outside octopus
param(
        [string]$serviceName,
        [string]$serviceType,
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

& {
    param(
            [string]$serviceName,
            [string]$serviceType
         ) 

        Write-Host "Setting $serviceName, $serviceType service autostart provider"

        try {
            Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
            Import-Module WebAdministration -ErrorAction SilentlyContinue

            $oldValue = Get-WebConfiguration -filter /system.applicationHost/serviceAutoStartProviders/add | 
                        Where-Object { $_.Name -eq $serviceName }

            if ($oldValue -eq $null) {
                Write-Host "Adding new service type provider $serviceName, $serviceType"
                Add-WebConfiguration -filter /system.applicationHost/serviceAutoStartProviders -Value @{name=$serviceName; type=$serviceType}
            } 
            elseif ($oldValue.Type -eq $serviceType) { 
                Write-Host "Service provider with the same name and type exists"
            } else {
                $oldValueType = $oldValue.Type
                Write-Host "Replacing service type from $oldValueType to $serviceType"
                Set-WebConfiguration -filter "/system.applicationHost/serviceAutoStartProviders/add[@name='$serviceName']" -Value @{"type" = "$serviceType"}
            }

            Write-Host "Done"
        } catch {
            Write-Host $_.Exception|format-list -force
            Write-Host "There was a problem setting property"    
        }
} `
(Get-Param 'serviceName' -Required) (Get-Param 'serviceType' -Required) 
