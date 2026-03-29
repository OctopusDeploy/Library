# Running outside octopus
param(
    [string]$webSiteName,
    [string]$propertyName,
    [string]$propertyValue,
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
        [string]$webSiteName,
        [string]$propertyName,
        [string]$propertyValue
    ) 

    Write-Host "Setting $webSiteName property $propertyName to $propertyValue"

    try {
         Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
         Import-Module WebAdministration -ErrorAction SilentlyContinue
         
         $oldValue = Get-ItemProperty "IIS:\Sites\$webSiteName" -Name $propertyName
         $oldValueString = ""

         
         if ($oldValue.GetType() -eq [Microsoft.IIs.PowerShell.Framework.ConfigurationAttribute])
         {
             $oldValueString = ($oldValue | Select-Object -ExpandProperty "Value")
         }
         elseif ($oldValue.GetType() -eq [System.String])
         {
             $oldValueString = $oldValue
         }
         elseif ($oldValue.GetType() -eq [System.Management.Automation.PSCustomObject])
         {
             $oldValueString = ($oldValue | Select-Object -ExpandProperty $propertyName)
         }

         Write-Host "Old value $oldValueString"
         Set-ItemProperty "IIS:\Sites\$webSiteName" -Name $propertyName -Value $propertyValue
         Write-Host "New value $propertyValue"
         Write-Host "Done"
    } catch {
        Write-Host $_.Exception|format-list -force
        Write-Host "There was a problem setting property"    
    }

 } `
 (Get-Param 'webSiteName' -Required) (Get-Param 'propertyName' -Required) (Get-Param 'propertyValue' -Required)
