$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

# use http://msdn.microsoft.com/en-us/library/windows/desktop/bb736357(v=vs.85).aspx for API reference

Function Create-ScheduledTask($TaskName,$RunAsUser,$RunAsPassword,$TaskRun, $Arguments, $Schedule,$StartTime,$StartDate)
{

    $argumentList = @();
    $argumentList += @( "/create" );
    $argumentList += @( "/ru", $RunAsUser );
    $argumentList += @( "/rp", $RunAsPassword );
    $argumentList += @( "/tn", "`"$TaskName`"" );
    $argumentList += @( "/sc", $Schedule );
    $argumentList += @( "/f" );

    if( $Arguments )
    {
        $argumentList += @( "/tr", "`"'$TaskRun' '$Arguments'`"" );
    }
    else
    {
        $argumentList += @( "/tr", "'$TaskRun'" );
    }

    if( -not (StringIsNullOrWhiteSpace($StartDate)) )
    {
        $argumentList += @( "/sd", $StartDate );
    }

    if( -not (StringIsNullOrWhiteSpace($StartTime)) )
    {
        $argumentList += @( "/st", $StartTime );
    }

    if( -not (StringIsNullOrWhiteSpace($Interval)) )
    {
        switch -Regex ($Schedule)
        {
            "MINUTE|HOURLY|ONLOGON|ONIDLE" {
                $argumentList += @( "/mo", $Interval );
            }
            "WEEKLY|MONTHLY"
            {
                $argumentList += @( "/ri", $Interval );
            }
            "ONCE|ONSTART|ONEVENT" {
                # we don't currently support providing an XPATH query string
                throw new-object System.NotImplementedException("Unsupported schedule option '$Schedule'.");
            }
        }
    }

    if( -not (StringIsNullOrWhiteSpace($Duration)) )
    {
        $argumentList += @( "/du", $Duration );
    }

    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList $argumentList;

}

Function Delete-ScheduledTask($TaskName) {
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/delete", "/s", "localhost", "/tn", "`"$TaskName`"", "/F" );
}

Function Stop-ScheduledTask($TaskName) {
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/end", "/s", "localhost", "/tn", "`"$TaskName`"" );
}

Function Start-ScheduledTask($TaskName) {
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/run", "/s", "localhost", "/tn", "`"$TaskName`"" );
}

Function Enable-ScheduledTask($TaskName) {
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/change", "/s", "localhost", "/tn", "`"$TaskName`"", "/ENABLE" );
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

function Invoke-CommandLine
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $FilePath,
        [Parameter(Mandatory=$false)]
        [string[]] $ArgumentList,
        [Parameter(Mandatory=$false)]
        [string[]] $SuccessCodes = @( 0 )
    )
    write-host ($FilePath + " " + ($ArgumentList -join " "));
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -NoNewWindow -PassThru;
    if( $SuccessCodes -notcontains $process.ExitCode )
    {
        throw new-object System.InvalidOperationException("process terminated with exit code '$($process.ExitCode)'.");
    }
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