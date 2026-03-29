Param(
    [string]$anc_WebConfigPath,
    [string]$anc_EnvironmentVariableName,
    [string]$anc_EnvironmentVariableValue
)

$ErrorActionPreference = "Stop"

function Get-Parameter($Name, [switch]$Required, [switch]$TestPath) {

    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null -or $result -eq "") {
        if ($Required) {
            throw "Missing parameter value $Name"
        }
    }

    if ($TestPath) {
        if (!(Test-Path $result -PathType Leaf)) {
            throw "Could not find $result"
        }
    }

    return $result
}

& {
    Param(
        [string]$anc_WebConfigPath,
        [string]$anc_EnvironmentVariableName,
        [string]$anc_EnvironmentVariableValue
    )

    $xml = (Get-Content $anc_WebConfigPath) -as [Xml]
    $aspNetCore = $xml.configuration.location.'system.webServer'.aspNetCore
    $environmentVariables = $aspNetCore.environmentVariables

    if (!$environmentVariables) {
        $environmentVariables = $xml.CreateElement("environmentVariables");
        $aspNetCore.AppendChild($environmentVariables)
    }

    $environmentVariable = $environmentVariables.environmentVariable | Where-Object {$_.name -eq $anc_EnvironmentVariableName}

    if ($environmentVariable) {
        $environmentVariable.value = $anc_EnvironmentVariableValue
    }
    elseif ($environmentVariables) {
        $environmentVariable = $xml.CreateElement("environmentVariable");
        $environmentVariable.SetAttribute("name", $anc_EnvironmentVariableName);
        $environmentVariable.SetAttribute("value", $anc_EnvironmentVariableValue);
        $x = $environmentVariables.AppendChild($environmentVariable)
    }
    else {
        throw "Could not find 'configuration/system.webServer/aspNetCore/environmentVariables' element in web.config"
    }

    try {
        $xml.Save((Resolve-Path $anc_WebConfigPath))
    }
    catch {
        throw "Could not save web.config because: $_.Exception.Message"
    }
} `
(Get-Parameter 'anc_WebConfigPath' -Required -TestPath) `
(Get-Parameter 'anc_EnvironmentVariableName' -Required) `
(Get-Parameter 'anc_EnvironmentVariableValue' -Required)
