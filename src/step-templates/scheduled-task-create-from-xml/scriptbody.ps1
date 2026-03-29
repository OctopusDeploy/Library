# Running outside octopus
param(
    [string]$xmlFileName,
    [string]$userName,
    [string]$password
)

$ErrorActionPreference = "Stop" 

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue    
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

Function Create-ScheduledTask($xmlFileName, $taskName, $username, $password){
	$Command = "schtasks.exe /create /tn $($taskName) /RU $($username) /RP $($password) /XML $($xmlFileName)"

	Write-Host $Command
	Invoke-Expression $Command
 }

Function Delete-ScheduledTask($TaskName) {   
	$Command = "schtasks.exe /delete /tn `"$TaskName`" /F"            
	Invoke-Expression $Command 
}

Function Stop-ScheduledTask($TaskName) {  
	$Command = "schtasks.exe /end /tn `"$TaskName`""            
	Invoke-Expression $Command 
}

Function Start-ScheduledTask($TaskName) {   
	$Command = "schtasks.exe /run /tn `"$TaskName`""            
	Invoke-Expression $Command 
}

Function ScheduledTask-Exists($taskName) {
   $schedule = new-object -com Schedule.Service 
   $schedule.connect() 
   $tasks = $schedule.getfolder("\").gettasks(0)

   foreach ($task in ($tasks | select Name)) {
	  #echo "TASK: $($task.name)"
	  if($task.Name -eq $taskName) {
		 #write-output "$task already exists"
		 return $true
	  }
   }

   return $false
}

Function GetTaskNameFromXmlPath($xmlFile){
    return (Split-Path -Path $xmlFile -Leaf -Resolve).Split(".")[0]
}

& {
    param(
        [string]$xmlFileName,
        [string]$userName,
        [string]$password
    ) 

    Write-Host "Create Schedule Task From XML"
    Write-Host "xmlFileName: $xmlFileName"
    Write-Host "userName: $userName"
    Write-Host "password: <Hidden>"

    $xmlFileName.Split(";") | foreach{
        $xmlFile = $_.Trim()
        $taskName = GetTaskNameFromXmlPath($xmlFile)


        if((ScheduledTask-Exists($taskName))){
	        Write-Output "$taskName already exists, Tearing down..."
	        Write-Output "Stopping $taskName..."
	        Stop-ScheduledTask($taskName)
	        Write-Output "Successfully Stopped $taskName"
	        Write-Output "Deleting $taskName..."
	        Delete-ScheduledTask($taskName)
	        Write-Output "Successfully Deleted $taskName"
        }

        Write-Output "Create a Scheduled Task from $xmlFile called $taskName. Run as $username" 
        Create-ScheduledTask "$($xmlFile)" $taskName $username $password
    }

}`
(Get-Param 'xmlFileName' -Required)`
(Get-Param 'userName' -Required)`
(Get-Param 'password' -Required)