$name = $OctopusParameters['rus_ServiceName']

$service = Get-Service -Name $name -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Host ">>> $name service not found. Skipping this time."
    return
}

Write-Host ">>> Uninstalling with: sc.exe"
if ($service.Status -eq 'Running') {
    &"sc.exe" stop $name | Write-Host
}
&"sc.exe" delete $name | Write-Host

$limit = 15
while (Get-Service -Name $name -ErrorAction SilentlyContinue) {
    Start-Sleep -s 1
    
    $limit = $limit - 1
    if ($limit -eq 0) {
        Throw "Unable to stop Redis service within 15s"
    }
}