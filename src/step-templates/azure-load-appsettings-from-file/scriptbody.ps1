Function Get-Parameter($Name, $Required, $Default, [switch]$FailOnValidate) {
    $result = $null
    $errMessage = [string]::Empty

    If ($null -ne $OctopusParameters) {
        $result = $OctopusParameters[$Name]
        Write-Host ("Octopus parameter value for " + $Name + ": " + $result)
    }

    If ($null -eq $result) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($null -ne $variable) {
            $result = $variable.Value
        }
    }

    If ($null -eq $result) {
        If ($Required) {
            $errMessage = "Mandatory parameter '$Name' not specified"
        }
        Else {
            $result = $Default
        }
    } 

    If (-Not [string]::IsNullOrEmpty($errMessage)) {
        If ($FailOnValidate) {
            Throw $errMessage
        }
        Else {
            Write-Warning $errMessage
        }
    }

    return $result
}

Function Main(
    [Parameter(Mandatory = $true)][string] $azureResourceGroupName,
    [Parameter(Mandatory = $true)][string] $azureWebAppName,
    [Parameter(Mandatory = $true)][string] $azureSettingsFilePath,
    [Parameter(Mandatory = $false)][string] $azureDeploySlotName = $null
) {
    Write-Host "Start AzureLoadAppSettingsFromFile"

    If ((Test-Path $azureSettingsFilePath) -ne $true) {
        Write-Warning "Settings file '$azureSettingsFilePath' not found!"
        Exit 0
    }

    $settingsJson = Get-Content -Raw -Path $azureSettingsFilePath | ConvertFrom-Json

    If (($settingsJson -eq $null) -or ($settingsJson.Values -eq $null)) {
        Write-Warning "Settings file '$azureSettingsFilePath' doesn't contain Values object. Unable to load app settings!"
        Exit 0
    }

    # Parse app settings into a hashtable object

    $settingsValues = $settingsJson.Values

    $appSettings = @{}
    $settingsValues.psobject.properties | Foreach { $appSettings[$_.Name] = $_.Value }

    # Set app settings for either slot or a webapp

    If ([string]::IsNullOrEmpty($azureDeploySlotName)) {
        Set-AzureRmWebApp -Name $azureWebAppName -ResourceGroupName $azureResourceGroupName -AppSettings $appSettings
    } Else {
        Set-AzureRmWebAppSlot -Name $azureWebAppName -ResourceGroupName $azureResourceGroupName -AppSettings $appSettings -Slot $azureDeploySlotName
    }

    Write-Host "End AzureLoadAppSettingsFromFile"
}

& Main `
    -azureResourceGroupName (Get-Parameter "Parameters.ResourceGroup.Name" $true "" $true) `
    -azureWebAppName (Get-Parameter "Parameters.WebApp.Name" $true "" $true) `
    -azureSettingsFilePath (Get-Parameter "Parameters.SettingsFile.Path" $true "" $true) `
    -azureDeploySlotName (Get-Parameter "Parameters.DeploySlot.Name" $false "" $true)