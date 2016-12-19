#use http://msdn.microsoft.com/en-us/library/windows/desktop/bb736357(v=vs.85).aspx for API reference

Function Create-ScheduledTask($TaskName,$RunAsUser,$RunAsPassword,$TaskRun,$Arguments,$Schedule,$StartTime,$StartDate,$RunWithElevatedPermissions,$Days,$Duration,$Interval)
{

    $commandArgs = @();

    $commandArgs += @( "/create" );

    $commandArgs += @( "/tn", $TaskName );
    if( $Arguments )
    {
        $commandArgs += @( "/tr", "`"'$TaskRun' '$Arguments'`"" );
    }
    else
    {
        $commandArgs += @( "/tr", "'$TaskRun'" );
    }

    $commandArgs += @( "/ru", $RunAsUser );
    $commandArgs += @( "/rp", $RunAsPassword );
    $commandArgs += @( "/sc", $Schedule );

    if(-Not (StringIsNullOrWhiteSpace($StartDate))) {
        $commandArgs += @( "/sd", $StartDate );
    }
    if(-Not (StringIsNullOrWhiteSpace($StartTime))) {
        $commandArgs += @( "/st", $StartTime );
    }
    if(-Not (StringIsNullOrWhiteSpace($Interval))) {
        switch -Regex ($Schedule)
        {
            "MINUTE|HOURLY|ONLOGON|ONIDLE" {
                $commandArgs += @( "/mo", $Interval );
            }
            "WEEKLY|MONTHLY" {
                $commandArgs += @( "/ri", $Interval );
            }
            "ONCE|ONSTART|ONEVENT" {
                 # We don't currently support providing an XPATH query string at the moment
                throw New-Object System.NotImplementedException("Unsupported schedule type '$Schedule'.");
            }
        }
    }
    if(-Not (StringIsNullOrWhiteSpace($Duration))) {
        $commandArgs += @( "/du", $Duration );
    }
    if($RunWithElevatedPermissions) {
        $commandArgs += @( "/rl", "HIGHEST" );
    }

    if(-Not (StringIsNullOrWhiteSpace($Days))) {
        if($Schedule -ne "WEEKDAYS") {
            $commandArgs += @( "/d", $Days );
        } else {
            $commandArgs += @( "/d", "MON,TUE,WED,THU,FRI" );
        }
    }

    $commandArgs += "/f"

    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList $commandArgs;

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
    write-host ($ArgumentList | % { "'$($_)'" } | fl * | out-string );
    if( $PSBoundParameters.ContainsKey("ArgumentList") )
    {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -NoNewWindow -PassThru;
    }
    else
    {
        $process = Start-Process -FilePath $FilePath -Wait -NoNewWindow -PassThru;
    }
    if( $SuccessCodes -notcontains $process.ExitCode )
    {
        throw new-object System.InvalidOperationException("process terminated with exit code '$($process.ExitCode)'.");
    }
}

function Invoke-OctopusStep
{
    param
    (
        [Parameter(Mandatory=$true)]
        [hashtable] $OctopusParameters
    )
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
    $runWithElevatedPermissions = [boolean]::Parse($OctopusParameters['RunWithElevatedPermissions'])
    $days = $OctopusParameters['Days']
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
    Create-ScheduledTask $taskName $runAsUser $runAsPassword $command $arguments $schedule $startTime $startDate $runWithElevatedPermissions $days $interval $duration
    Write-Output "Successfully Created $taskName"
    Enable-ScheduledTask($taskName)
    Write-Output "$taskName enabled"
}

# don't execute the step if we're running Pester tests
if( Test-Path -Path "Variable:OctopusParameters" )
{
    Invoke-OctopusStep -OctopusParameters $OctopusParameters;
}