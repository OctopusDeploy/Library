$svcName = $OctopusParameters['ServiceName']
$svcTimeout = $OctopusParameters['ServiceStopTimeout']

function Stop-ServiceWithTimeout ([string] $name, [int] $timeoutSeconds) {
    $timespan = New-Object -TypeName System.Timespan -ArgumentList 0,0,$timeoutSeconds

    If ($svc = Get-Service $svcName -ErrorAction SilentlyContinue) {
        if ($null -eq $svc) { return $true }
        if ($svc.Status -eq [ServiceProcess.ServiceControllerStatus]::Stopped) { return $true }
        try {
            Write-Host "Stopping Service with Timeout" $svcTimeout "seconds"
            $svc.Stop()
            $svc.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped, $timespan)
        }
        catch [ServiceProcess.TimeoutException] {
            Write-Host "Timeout stopping service $($svc.Name)"
            return $false
        }
        catch {
            Write-Warning "Service $svcName could not be stopped: $_"
        }
        Write-Host "Service Sucessfully stopped"

    } Else {
        Write-Host "Service does not exist, this is acceptable. Probably the first time deploying to this target"
        Exit
    }
}

Write-Host "Checking service $svcName"
try {
    $svc = Get-Service $svcName
}
catch {
    if ($null -eq $svc) { Write-Warning "Service $svcName not found." }
    exit 1
}

$svcpid1 = (get-wmiobject Win32_Service | Where-Object{$_.Name -eq $svcName}).ProcessId
if($svcpid1 -ne 0) {
    Write-Host "Found PID $svcpid1 - stopping service now..."
    Stop-ServiceWithTimeout -name $svcName -timeoutSeconds $svcTimeout
}
else {
    Write-Host "No PID found for $svcName - service is already stopped."
    exit 0
}

Write-Host "Rechecking service"
$svcpid2 = (get-wmiobject Win32_Service | Where-Object{$_.Name -eq $svcName}).ProcessId
if($svcpid2 -eq 0) {
    Write-Host "no PID found for $svcName"
}
else {
    Write-Warning "PID $svcpid2 found for $svcName - service not stopped. Trying to Kill the process."
}

$service = Get-Service -name $svcName | Select-Object -Property Status
if($service.Status -ne "Stopped"){
    Start-Sleep -seconds 5
    $p = get-process -id $svcpid2 -ErrorAction SilentlyContinue
    if($p){
        Write-Host "Killing PID" $p.id "(" $p.Name ")"
        try {
            Stop-Process $p.Id -force
        }
        catch {
            Write-Warning "process" $p.id "could not be stopped:" $_
        }
    }
}
