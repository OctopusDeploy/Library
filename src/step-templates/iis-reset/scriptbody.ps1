$wait = $OctopusParameters["iisWait"] -and [boolean]::Parse($OctopusParameters["iisWait"])
$action = $OctopusParameters["iisAction"]
$errorAction = $OctopusParameters["iisErrorAction"]
if ($Action -eq "/RESTART") { Write-Host "Restarting IIS" }
elseif ($Action -eq "/START") { Write-Host "Starting IIS" }
elseif ($Action -eq "/STOP") { Write-Host "Stopping IIS" }
else {
    Write-Error "Unknown action $action"
    exit 1
}

if (($errorAction -ne "Stop") -and ($errorAction -ne "Continue") -and ($errorAction -ne "SilentlyContinue")) {
    Write-Error "Unknown ErrorAction $errorAction"
    exit 1
}

if ($wait) {
    Write-Host "Running with wait"
    Start-Process -FilePath "iisreset" -ArgumentList $Action -ErrorAction $OctopusParameters["iisErrorAction"] -Wait
}
else {
    Write-Host "Running without wait"
    Start-Process -FilePath "iisreset" -ArgumentList $Action -ErrorAction $OctopusParameters["iisErrorAction"]
}
