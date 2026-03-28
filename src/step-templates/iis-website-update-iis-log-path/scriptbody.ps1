write-host "#Updating IIS Log path"

Import-Module "WebAdministration" -ErrorAction Stop

$logPath = $OctopusParameters['LogPath']
$IISsitename = $OctopusParameters['webSiteName']

if (!(Test-Path "IIS:\Sites\$($IISsitename)")) {
    write-host "$IISsitename does not exist in IIS"
} else {
    $currentLogPath = (Get-ItemProperty IIS:\Sites\$($IISsitename)).logFile.directory
    write-host "IIS LogPath currently set to $currentLogPath"
    if ([string]::Compare($currentLogPath, $logPath, $True) -ne 0) {
        Set-ItemProperty IIS:\Sites\$($IISsitename) -name logFile.directory -value $logPath
        write-host "IIS LogPath updated to $logPath"
    }
}