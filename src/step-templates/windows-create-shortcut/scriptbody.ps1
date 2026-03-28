$destination = $OctopusParameters['ShortcutDestination']
$targetFilePath = $OctopusParameters['TargetFilePath']
$shortcutName = $OctopusParameters['Shortcutname']

#Use Custom or predefined path
$shortcutDestination = 
    if($destination -eq "PublicDesktop") { "$env:PUBLIC\Desktop" }
    elseif($destination -eq "Custom") { $OctopusParameters['ShortcutPath'] }
    else {Write-Error "Shortcut destination is not set"}


#Create shortcut filename
$shortcut = "$shortcutDestination\$shortcutName.lnk"

Write-Output "Shortcut: $shortcut"
Write-Output "Target: $targetFilePath"

if(!(Test-Path $destination)){
    New-Item -ItemType Directory -Path $destination
}

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$shortcut")
$Shortcut.TargetPath = $targetFilePath
$Shortcut.Save()