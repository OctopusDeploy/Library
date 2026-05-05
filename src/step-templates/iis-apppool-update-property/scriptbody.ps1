# Running outside octopus
param(
    [string]$appPoolName,
    [string]$propertyName,
    [object]$propertyValue,
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
        [string]$appPoolName,
        [string]$propertyName,
        [object]$propertyValue
    )

    Write-Host "Setting $appPoolName property $propertyName to $propertyValue"

    try {
         Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
         Import-Module WebAdministration -ErrorAction SilentlyContinue

         $oldValue = Get-ItemProperty "IIS:\AppPools\$appPoolName" -Name $propertyName
         $oldValueString = ""

         if ($oldValue.GetType() -eq [Microsoft.IIs.PowerShell.Framework.ConfigurationAttribute])
         {
             $oldValueString = ($oldValue | Select-Object -ExpandProperty "Value");
             $convertedValue = $propertyValue -as $oldValueString.GetType();
         }
         else
         {
             $oldValueString = $oldValue;
             $convertedValue = $propertyValue -as $oldValue.GetType();
         }

         Write-Host "Old value $oldValueString"
         Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name $propertyName -Value $convertedValue
         Write-Host "New value $propertyValue"
         Write-Host "Done"
    } catch {
        Write-Host $_.Exception|format-list -force
        Write-Host "There was a problem setting property"
    }

 } `
 (Get-Param 'appPoolName' -Required) (Get-Param 'propertyName' -Required) (Get-Param 'propertyValue' -Required)
