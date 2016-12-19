#use http://msdn.microsoft.com/en-us/library/windows/desktop/bb736357(v=vs.85).aspx for API reference

Function Create-ScheduledTask($TaskName,$RunAsUser,$RunAsPassword,$TaskRun, $Arguments, $Schedule,$StartTime,$StartDate){
    
    $cmdStartDate = if(StringIsNullOrWhiteSpace($StartDate)){""}else{"/sd $StartDate"}
    $cmdStartTime = if(StringIsNullOrWhiteSpace($StartTime)){""}else{"/st $StartTime"}
    $cmdInterval = if(StringIsNullOrWhiteSpace($Interval)){""}else{Validate-ScheduleAndParams($Schedule)}
    $cmdDuration = if(StringIsNullOrWhiteSpace($Duration)){""}else{"/du $Duration"}
    
    $cmd = "'$($TaskRun)'"
    if($Arguments) {
        $cmd = "'$TaskRun' '$Arguments'"
    }

    $Command = "schtasks.exe /create /ru $RunAsUser /rp '$RunAsPassword' /tn `"$TaskName`" /tr `"$cmd`" /sc $Schedule $cmdStartDate $cmdStartTime /F $cmdInterval $cmdDuration"
    
    echo $Command          
    Invoke-Expression $Command            
}

Function Validate-ScheduleAndParams($Schedule) {
  switch -Regex ($Schedule) 
    {
      "MINUTE|HOURLY|ONLOGON|ONIDLE"  { "/MO $interval"; break }
      "WEEKLY|MONTHLY"  { "/ri $interval"; break }
      "ONCE|ONSTART|ONEVENT"    { ""; break } # We don't currently support providing an XPATH query string at the moment
    }
}
Function Delete-ScheduledTask($TaskName) {   
    $Command = "schtasks.exe /delete /s localhost /tn `"$TaskName`" /F"            
    Invoke-Expression $Command 
}

Function Stop-ScheduledTask($TaskName) {  
    $Command = "schtasks.exe /end /s localhost /tn `"$TaskName`""            
    Invoke-Expression $Command 
}

Function Start-ScheduledTask($TaskName) {   
    $Command = "schtasks.exe /run /s localhost /tn `"$TaskName`""            
    Invoke-Expression $Command 
}

Function Enable-ScheduledTask($TaskName) {  
    $Command = "schtasks.exe /change /s localhost /tn `"$TaskName`" /ENABLE"            
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

Function StringIsNullOrWhitespace([string] $string)
{
    if ($string -ne $null) { $string = $string.Trim() }
    return [string]::IsNullOrEmpty($string)
}

$taskName = $OctopusParameters['TaskName']
$runAsUser = $OctopusParameters['RunAsUser']
$runAsPassword = $OctopusParameters['RunAsPassword']
$command = $OctopusParameters['Command']
$arguments = $OctopusParameters['Arguments']
$schedule = $OctopusParameters['Schedule']
$startTime = $OctopusParameters['StartTime']
$startDate = $OctopusParameters['StartDate']
$interval = $OctopusParameters['Interval']
$duration = $OctopusParameters['Duration']


if((ScheduledTask-Exists($taskName))){
    Write-Output "$taskName already exists, Tearing down..."
    Write-Output "Stopping $taskName..."
    Stop-ScheduledTask($taskName)
    Write-Output "Successfully Stopped $taskName"
    Write-Output "Deleting $taskName..."
    Delete-ScheduledTask($taskName)
    Write-Output "Successfully Deleted $taskName"
}
Write-Output "Creating Scheduled Task - $taskName"

Create-ScheduledTask $taskName $runAsUser $runAsPassword $command $arguments $schedule $startTime $startDate
Write-Output "Successfully Created $taskName"
Enable-ScheduledTask($taskName)
Write-Output "$taskName enabled"