function Validate-Parameter {
    Param(
        [Parameter(Position=0)][string]$Parameter,
        [Parameter(Mandatory=$true, Position=1)][string]$ParameterName
    )
    if (!$ParameterName -contains 'Password') {
        Write-Host ('{0}: {1}' -f ${ParameterName},$Parameter)
    }
    if (!$Parameter) {
        Write-Error ('No value was set for {0}, and it cannot be empty' -f $ParameterName)
    }
}

function Execute-Retry {
    Param(
        [Parameter(Mandatory=$true, Position=0)][ScriptBlock]$Command
    )
	$attemptCount = 0
	$operationIncomplete = $true
    $maxFailures = 5
    $sleepBetweenFailures = Get-Random -minimum 1 -maximum 4
	while ($operationIncomplete -and $attemptCount -lt $maxFailures) {
		$attemptCount = ($attemptCount + 1)
		if ($attemptCount -ge 2) {
			Write-Output ('Waiting for {0} seconds before retrying ...' -f $sleepBetweenFailures)
			Start-Sleep -s $sleepBetweenFailures
			Write-Output 'Retrying ...'
		}
		try {
			& $Command
			$operationIncomplete = $false
		} catch [System.Exception] {
			if ($attemptCount -lt ($maxFailures)) {
				Write-Output ('Attempt {0} of {1} failed: {2}' -f $attemptCount,$maxFailures,$_.Exception.Message)
			}
			else {
                Write-Host 'Failed to execute command'
			}
		}
	}
}

function Get-ScheduledTimes {
    Param(
        [Parameter(Position=0)][string]$Schedule
    )
    if (!$Schedule) {
        return @()
    }
    $minutes = $Schedule.Split(',')
    $minuteArrayList = New-Object System.Collections.ArrayList(,$minutes)
    return $minuteArrayList
}

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Web.Administration')
Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue

$appPoolName = $OctopusParameters['AppPoolName']
$appPoolIdentityType = $OctopusParameters['AppPoolIdentityType']
if ($appPoolIdentityType -eq 3) {
    $appPoolIdentityUser = $OctopusParameters['AppPoolIdentityUser']
    $appPoolIdentityPassword = $OctopusParameters['AppPoolIdentityPassword']
}
$appPoolLoadUserProfile = [boolean]::Parse($OctopusParameters['AppPoolLoadUserProfile'])
$appPoolAutoStart = [boolean]::Parse($OctopusParameters['AppPoolAutoStart'])
$appPoolEnable32BitAppOnWin64 = [boolean]::Parse($OctopusParameters['AppPoolEnable32BitAppOnWin64'])
$appPoolManagedRuntimeVersion = $OctopusParameters['AppPoolManagedRuntimeVersion']
$appPoolManagedPipelineMode = $OctopusParameters['AppPoolManagedPipelineMode']
$appPoolIdleTimeout = [TimeSpan]::FromMinutes($OctopusParameters['AppPoolIdleTimeoutMinutes'])
$appPoolPeriodicRecycleTime = $OctopusParameters['AppPoolPeriodicRecycleTime']
$appPoolMaxProcesses = [int]$OctopusParameters['AppPoolMaxProcesses']
$appPoolRegularTimeInterval = [TimeSpan]::FromMinutes($OctopusParameters['AppPoolRegularTimeInterval'])
$appPoolQueueLength = [int]$OctopusParameters['AppPoolQueueLength']
$appPoolStartMode = $OctopusParameters['AppPoolStartMode']
$appPoolCpuAction = $OctopusParameters['AppPoolCpuLimitAction']
$appPoolCpuLimit = [int]$OctopusParameters['AppPoolCpuLimit']

Validate-Parameter -Parameter $appPoolName -ParameterName 'Application Pool Name'
Validate-Parameter -Parameter $appPoolIdentityType -ParameterName 'Identity Type'
if ($appPoolIdentityType -eq 3) {
    Validate-Parameter -Parameter $appPoolIdentityUser -ParameterName 'Identity UserName'
    # If using Group Managed Serice Accounts, the password should be allowed to be empty
}
Validate-Parameter -Parameter $appPoolLoadUserProfile -parameterName 'Load User Profile'
Validate-Parameter -Parameter $appPoolAutoStart -ParameterName 'AutoStart'
Validate-Parameter -Parameter $appPoolEnable32BitAppOnWin64 -ParameterName 'Enable 32-Bit Apps on 64-bit Windows'
Validate-Parameter -Parameter $appPoolManagedRuntimeVersion -ParameterName 'Managed Runtime Version'
Validate-Parameter -Parameter $appPoolManagedPipelineMode -ParameterName 'Managed Pipeline Mode'
Validate-Parameter -Parameter $appPoolIdleTimeout -ParameterName 'Process Idle Timeout'
Validate-Parameter -Parameter $appPoolMaxProcesses -ParameterName 'Maximum Worker Processes'
Validate-Parameter -Parameter $appPoolStartMode -parameterName 'Start Mode'
Validate-Parameter -Parameter $appPoolCpuAction -parameterName 'CPU Limit Action'
Validate-Parameter -Parameter $appPoolCpuLimit -parameterName 'CPU Limit (percent)'

$iis = (New-Object Microsoft.Web.Administration.ServerManager)
$pool = $iis.ApplicationPools | Where-Object {$_.Name -eq $appPoolName} | Select-Object -First 1
if ($pool -eq $null) {
    Write-Output ('Creating Application Pool {0}' -f $appPoolName)
    Execute-Retry {
        $iis = (New-Object Microsoft.Web.Administration.ServerManager)
        $iis.ApplicationPools.Add($appPoolName)
        $iis.CommitChanges()
    }
}
else {
    Write-Output ('Application Pool {0} already exists, reconfiguring ...' -f $appPoolName)
}
$list = Get-ScheduledTimes -Schedule $appPoolPeriodicRecycleTime
Execute-Retry {
    $iis = (New-Object Microsoft.Web.Administration.ServerManager)
    $pool = $iis.ApplicationPools | Where-Object {$_.Name -eq $appPoolName} | Select-Object -First 1
    Write-Output ('Setting: AutoStart = {0}' -f $appPoolAutoStart)
    $pool.AutoStart = $appPoolAutoStart
    Write-Output ('Setting: Enable32BitAppOnWin64 = {0}' -f $appPoolEnable32BitAppOnWin64)
    $pool.Enable32BitAppOnWin64 = $appPoolEnable32BitAppOnWin64
    Write-Output ('Setting: IdentityType = {0}' -f $appPoolIdentityType)
    $pool.ProcessModel.IdentityType = $appPoolIdentityType
    if ($appPoolIdentityType -eq 3) {
        Write-Output ('Setting: UserName = {0}' -f $appPoolIdentityUser)
        $pool.ProcessModel.UserName = $appPoolIdentityUser
        if (!$appPoolIdentityPassword) {
            Write-Output ('Setting: Password = [empty]')
        }
        else {
            Write-Output ('Setting: Password = [Omitted For Security]')
        }
        $pool.ProcessModel.Password = $appPoolIdentityPassword
    }
	Write-Output ('Setting: LoadUserProfile = {0}' -f $appPoolLoadUserProfile)
    $pool.ProcessModel.LoadUserProfile = $appPoolLoadUserProfile
    Write-Output ('Setting: ManagedRuntimeVersion = {0}' -f $appPoolManagedRuntimeVersion)
    if ($appPoolManagedRuntimeVersion -eq 'No Managed Code') {
        $pool.ManagedRuntimeVersion = ''
    }
    else {
        $pool.ManagedRuntimeVersion = $appPoolManagedRuntimeVersion
    }
    Write-Output ('Setting: ManagedPipelineMode = {0}' -f $appPoolManagedPipelineMode)
    $pool.ManagedPipelineMode = $appPoolManagedPipelineMode
    Write-Output ('Setting: IdleTimeout = {0}' -f $appPoolIdleTimeout)
    $pool.ProcessModel.IdleTimeout = $appPoolIdleTimeout
    Write-Output ('Setting: MaxProcesses = {0}' -f $appPoolMaxProcesses)
    $pool.ProcessModel.MaxProcesses = $appPoolMaxProcesses
    Write-Output ('Setting: RegularTimeInterval = {0}' -f $appPoolRegularTimeInterval)
    $pool.Recycling.PeriodicRestart.Time  = $appPoolRegularTimeInterval
    Write-Output ('Setting: QueueLength = {0}' -f $appPoolQueueLength)
    $pool.QueueLength  = $appPoolQueueLength
    Write-Output ('Setting: CPU Limit (percent) = {0}' -f $appPoolCpuLimit)
    ## Limit is stored in 1/1000s of one percent
    $pool.Cpu.Limit = $appPoolCpuLimit * 1000
    Write-Output ('Setting: CPU Limit Action = {0}' -f $appPoolCpuAction)
    $pool.Cpu.Action = $appPoolCpuAction
    Write-Output ('Setting: Schedule = {0}' -f $appPoolPeriodicRecycleTime)
    $pool.Recycling.PeriodicRestart.Schedule.Clear()
    foreach($timestamp in $list) {
        $pool.Recycling.PeriodicRestart.Schedule.Add($timestamp)
    }
    if (Get-Member -InputObject $pool -Name StartMode -MemberType Properties)
    {
        Write-Output ('Setting: StartMode = {0}' -f $appPoolStartMode)
        $pool.StartMode = $appPoolStartMode
    }
    else
    {
        Write-Output ('IIS does not support StartMode property, skipping this property...')
    }
    $iis.CommitChanges()
}