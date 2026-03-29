Import-Module WebAdministration

function Update-IISAppPool-PeriodicRestart($appPool, $periodicRestart) {
    Write-Output "Setting worker process periodic restart time to $periodicRestart for AppPool $appPoolName."
    $appPool.Recycling.PeriodicRestart.Time = [TimeSpan]::FromMinutes($periodicRestart)
    $appPool | Set-Item
}

function Update-IISAppPool-IdleTimeout($appPool, $appPoolName, $idleTimeout) {
    Write-Output "Setting worker process idle timeout to $idleTimeout for AppPool $appPoolName."
    $appPool.ProcessModel.IdleTimeout = [TimeSpan]::FromMinutes($idleTimeout)
    $appPool | Set-Item
}

function Update-IISAppPool-ScheduledTimes($appPool, $appPoolName, $schedule) {
    $minutes = $periodicRecycleTimes.Split(",")
    $minuteArrayList = New-Object System.Collections.ArrayList

    foreach ($minute in $minutes) {
        $minute = $minute.trim()

        if ($minute -eq "-1") {
            break
        }
        if ($minute -lt 0) {
            continue
        }

        $minuteArrayList.Add([TimeSpan]::FromMinutes($minute))
    }

    Write-Output "Setting worker process scheduled restart times to $minuteArrayList for AppPool $appPoolName."

    $settingName = "recycling.periodicRestart.schedule"
    Clear-ItemProperty $appPool.PSPath -Name $settingName

    $doneOne = $false
    foreach ($minute in $minuteArrayList) {
        if ($doneOne -eq $false) {
            Set-ItemProperty $appPool.PSPath -Name $settingName -Value @{value=$minute}
            $doneOne = $true
        }
        else {
            New-ItemProperty $appPool.PSPath -Name $settingName -Value @{value=$minute}
        }
    }
}

function Update-IISAppPool-RecycleEventsToLog($appPool, $appPoolName, $events) {
    $settingName = "Recycling.logEventOnRecycle"
    Write-Output "Setting $settingName for AppPool $appPoolName to $events."

    Clear-ItemProperty $appPool.PSPath -Name $settingName
    if ($events -ne "-") {
        Set-ItemProperty $appPool.PSPath -Name $settingName -Value $events
    }
}

function Update-IISAppPool-PrivateMemoryLimit($appPool, $appPoolName, $privateMemoryLimitKB) {
    Write-Output "Setting private memory limit to $privateMemoryLimitKB KB for AppPool $appPoolName."
    $appPool.Recycling.PeriodicRestart.PrivateMemory = $privateMemoryLimitKB
    $appPool | Set-Item
}

function Run {
    $OctopusParameters = $OctopusParameters
    if ($null -eq $OctopusParameters) {
        write-host "Using test values"
        $OctopusParameters = New-Object "System.Collections.Hashtable"
        $OctopusParameters["ApplicationPoolName"]="DefaultAppPool"
        $OctopusParameters["IdleTimeoutMinutes"]=""
        $OctopusParameters["RegularTimeIntervalMinutes"]="10"
        $OctopusParameters["PeriodicRecycleTime"]="14,15,16"
        $OctopusParameters["RecycleEventsToLog"]="Time, Requests, Schedule, Memory, IsapiUnhealthy, OnDemand, ConfigChange, PrivateMemory"
        $OctopusParameters["PrivateMemoryLimitKB"]="1024000"
        $OctopusParameters["EmptyClearsValue"]=$true
    }

    $applicationPoolName = $OctopusParameters["ApplicationPoolName"]
    $idleTimeout = $OctopusParameters["IdleTimeoutMinutes"]
    $periodicRestart = $OctopusParameters["RegularTimeIntervalMinutes"]
    $periodicRecycleTimes = $OctopusParameters["PeriodicRecycleTime"]
    $recycleEventsToLog = $OctopusParameters["RecycleEventsToLog"]
    $privateMemoryLimitKB = $OctopusParameters["PrivateMemoryLimitKB"]
    $emptyClearsValue = $OctopusParameters["EmptyClearsValue"]

    if ([string]::IsNullOrEmpty($applicationPoolName)) {
        throw "Application pool name is required."
    }

    $appPool = Get-Item IIS:\AppPools\$applicationPoolName

    if ($emptyClearsValue -eq $true) {
        Write-Output "Empty values will reset to default"
        if ([string]::IsNullOrEmpty($idleTimeout)) {
            $idleTimeout = "0"
        }
        if ([string]::IsNullOrEmpty($periodicRestart)) {
            $periodicRestart = "0"
        }
        if ([string]::IsNullOrEmpty($periodicRecycleTimes)) {
            $periodicRecycleTimes = "-1"
        }
        if ([string]::IsNullOrEmpty($recycleEventsToLog)) {
            $recycleEventsToLog = "-"
        }
        if ([string]::IsNullOrEmpty($privateMemoryLimitKB)) {
            $privateMemoryLimitKB = "0"
        }
    }

    if (![string]::IsNullOrEmpty($periodicRestart)) {
        Update-IISAppPool-PeriodicRestart              -appPool $appPool -appPoolName $appPool.Name -PeriodicRestart $periodicRestart
    }
    if (![string]::IsNullOrEmpty($idleTimeout)) {
        Update-IISAppPool-IdleTimeout                  -appPool $appPool -appPoolName $appPool.Name -idleTimeout $idleTimeout
    }
    if (![string]::IsNullOrEmpty($periodicRecycleTimes)) {
        Update-IISAppPool-ScheduledTimes               -appPool $appPool -appPoolName $appPool.Name -Schedule $periodicRecycleTimes
    }
    if(![string]::IsNullOrEmpty($recycleEventsToLog)){
        Update-IISAppPool-RecycleEventsToLog           -appPool $appPool -appPoolName $appPool.Name -Events $recycleEventsToLog
    }
    if (![string]::IsNullOrEmpty($privateMemoryLimitKB)) {
        Update-IISAppPool-PrivateMemoryLimit           -appPool $appPool -appPoolName $appPool.Name -PrivateMemoryLimitKB $privateMemoryLimitKB
    }
}

Run
