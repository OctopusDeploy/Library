$ErrorActionPreference = "Stop" 
$configFiles = $OctopusParameters["Sitecore.ReplaceConfigFiles"]

if ([string]::IsNullOrEmpty($configFiles)) {
    throw [System.ArgumentNullException] "Sitecore.ReplaceConfigFiles"
}

($configFiles -split '[\r\n]') | ForEach-Object {
    
    $configPath = $_

    if ([string]::IsNullOrEmpty($configPath)) { 
        return
    }
    
    $configPath = $configPath.Trim()

    if (-not (Test-Path -LiteralPath $configPath)) {
        Write-Host "$configPath was not found."
        return
    }

    Write-Host "Searching Sitecore config file for replacement variables:" $configPath
        
    $configXml = [xml](Get-Content $configPath)
    $sitecoreNode = $configXml.sitecore
    
    # Look for sitecore node for versions prior to 8.1
    if ($sitecoreNode -eq $null) {
        $sitecoreNode = $configXml.configuration.sitecore
    }
    
    # Ensure that we have a sitecore node to work from
    if ($sitecoreNode -eq $null -or $sitecoreNode.settings -eq $null) {
        Write-Host "The sitecore settings node was not found in" $configPath ". Skipping this file..."
        return
    }
    
    foreach ($key in $OctopusParameters.Keys) {
    
        # Replace Sitecore settings
        $setting = $sitecoreNode.settings.setting | where { $_.name -ceq $key }
        if ($setting -ne $null) {
            Write-Host $setting.name "setting will be updated from" $setting.value "to" $OctopusParameters[$key] "in" $configPath
            $setting.value = $OctopusParameters[$key]
        }
    
        # Replace Sitecore variables
        $variable = $sitecoreNode.'sc.variable' | where { $_.name -ceq $key }
        if ($variable -ne $null) {
            Write-Host $variable.name "Sitecore variable will be updated from" $settingsNode.value "to" $OctopusParameters[$key] "in" $configPath
            $variable.value = $OctopusParameters[$key]
        }
    
    }
    
    $configXml.Save($configPath)
}