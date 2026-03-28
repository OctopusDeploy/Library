function AddOrReplaceEnvironmentVariable {
    param
    (
        [string] $variableName, 
        [string] $variableValue,
        [string] $siteName,
        [string] $appCmd
    )

    Try {
        [xml] $xmlConfig = (&$appCmd list config $sev_siteName -section:system.webServer/aspNetCore)
    }
    Catch {
        Write-Host $sev_siteName 'either does not exist or is not an AspNetCore site!'
        exit -1
    }

    if($xmlConfig.selectNodes("//environmentVariable[@name='$variableName']")) {
        &$appCmd set config $sev_siteName -section:system.webServer/aspNetCore /-"environmentVariables.[name='$variableName',value='$variableValue']" /commit:apphost
    }
    
    &$appCmd set config $sev_siteName -section:system.webServer/aspNetCore /+"environmentVariables.[name='$variableName',value='$variableValue']" /commit:apphost
}

[string] $sev_siteName=$OctopusParameters['sev_siteName']
[string] $sev_envVariables=$OctopusParameters['sev_envVariables']
[string] $sev_appCmdPath=$OctopusParameters['sev_appCmdPath']

Write-Host "---------------------------"
Write-Host $sev_envVariables
Write-Host $sev_appCmdPath
Write-Host "---------------------------"

$appCmd = Join-Path $sev_appCmdPath 'appcmd.exe'

foreach($line in $sev_envVariables -split '\r?\n') {
    $indexOfEquals = $line.IndexOf('=')
    if ($indexOfEquals -eq -1) {
        Write-Host "Invalid environment variable format: $line"
        continue
    }
    $key = $line.Substring(0, $indexOfEquals)
    $value = $line.Substring($indexOfEquals + 1)

    AddOrReplaceEnvironmentVariable $key $value $sev_siteName $appCmd
}
