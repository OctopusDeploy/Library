$taskName = $OctopusParameters['TaskName']
$maximumWaitTime = $OctopusParameters['MaximumWaitTime']
$succeedOnTaskNotFound = $OctopusParameters['SucceedOnTaskNotFound']

#Check if the PowerShell cmdlets are available
$cmdletSupported = [bool](Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue)

try {
	if($cmdletSupported) {
		$taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName }
	}
	else {
		$taskService = New-Object -ComObject "Schedule.Service"
		$taskService.Connect()
		$taskFolder = $taskService.GetFolder('\')
		$taskExists = $taskFolder.GetTasks(0) | Select-Object Name, State | Where-Object { $_.Name -eq $taskName }
	}

	if(-not $taskExists) {
        if( $succeedOnTaskNotFound){
            Write-Output "Scheduled task '$taskName' does not exist"
            }
        else {
		    throw "Scheduled task '$taskName' does not exist"
        }
		return
	}

	Write-Output "Disabling $taskName..."
	$waited = 0
	if($cmdletSupported) {
		$task = Disable-ScheduledTask $taskName
		Write-Output "Waiting until $taskName is disabled..."
		while(($task.State -ne [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]::Disabled) -and (($maximumWaitTime -eq 0) -or ($waited -lt $maximumWaitTime))) 
		{
			Start-Sleep -Milliseconds 200
			$waited += 200
			$task = Get-ScheduledTask $taskName
		}
		
		if($task.State -ne [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]::Disabled) {
			throw "The scheduled task $taskName could not be disabled within the specified wait time"
		}
	}
	else {
		schtasks /Change /Disable /TN "$taskName"
		#The State property can hold the following values:
		# 0: Unknown
		# 1: Disabled
		# 2: Queued
		# 3: Ready
		# 4: Running
		while(($taskFolder.GetTask($taskName).State -ne 1) -and (($maximumWaitTime -eq 0) -or ($waited -lt $maximumWaitTime))) {
			Start-Sleep -Milliseconds 200
			$waited += 200
		}
		
		if($taskFolder.GetTask($taskName).State -ne 1) {
		    throw "The scheduled task '$taskName' could not be disabled within the specified wait time"
		}
	}
}
finally {
    if($taskFolder -ne $NULL) {
	    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($taskFolder)   
	}
	
	if($taskService -ne $NULL) {
	    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($taskService)   
	}
}