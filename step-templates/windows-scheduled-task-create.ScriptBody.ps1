$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

# use http://msdn.microsoft.com/en-us/library/windows/desktop/bb736357(v=vs.85).aspx for API reference

Function Create-ScheduledTask($TaskName,$RunAsUser,$RunAsPassword,$TaskRun,$Arguments,$Schedule,$StartTime,$StartDate,$RunWithElevatedPermissions,$Days,$Interval,$Duration)
{

    # SCHTASKS /Create [/S system [/U username [/P [password]]]]
    #     [/RU username [/RP password]] /SC schedule [/MO modifier] [/D day]
    #     [/M months] [/I idletime] /TN taskname /TR taskrun [/ST starttime]
    #     [/RI interval] [ {/ET endtime | /DU duration} [/K] [/XML xmlfile] [/V1]]
    #     [/SD startdate] [/ED enddate] [/IT | /NP] [/Z] [/F] [/HRESULT] [/?]

    # note - /RL and /DELAY appear in the "Parameter list" for "SCHTASKS /Create /?" but not in the syntax above

    $argumentList = @();
    $argumentList += @( "/Create" );

    $argumentList += @( "/RU", $RunAsUser );
    $argumentList += @( "/RP", $RunAsPassword );

    $argumentList += @( "/SC", $Schedule );

    if( -not (StringIsNullOrWhiteSpace($Interval)) )
    {
        switch -Regex ($Schedule)
        {
            "MINUTE|HOURLY|ONLOGON|ONIDLE" {
                $argumentList += @( "/MO", $Interval );
            }
            "WEEKLY|MONTHLY" {
                $argumentList += @( "/RI", $Interval );
            }
            "ONCE|ONSTART|ONEVENT" {
                # we don't currently support providing an XPATH query string
                throw new-object System.NotImplementedException("Unsupported schedule option '$Schedule'.");
            }
        }
    }

    if( -not (StringIsNullOrWhiteSpace($Days)) )
    {
        if($Schedule -ne "WEEKDAYS") {
            $argumentList += @( "/D", $Days );
        } else {
            $argumentList += @( "/D", "MON,TUE,WED,THU,FRI" );
        }
    }

    $argumentList += @( "/TN", "`"$TaskName`"" );

    if( $Arguments )
    {
        $argumentList += @( "/TR", "`"'$TaskRun' '$Arguments'`"" );
    }
    else
    {
        $argumentList += @( "/TR", "'$TaskRun'" );
    }

    if( -not (StringIsNullOrWhiteSpace($StartTime)) )
    {
        $argumentList += @( "/ST", $StartTime );
    }

    if( -not (StringIsNullOrWhiteSpace($Duration)) )
    {
        $argumentList += @( "/DU", $Duration );
    }

    if( -not (StringIsNullOrWhiteSpace($StartDate)) )
    {
        $argumentList += @( "/SD", $StartDate );
    }

    $argumentList += @( "/F" );

    if( $RunWithElevatedPermissions )
    {
        $argumentList += @( "/RL", "HIGHEST" );
    }

    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList $argumentList;

}

Function Delete-ScheduledTask($TaskName) {
    # SCHTASKS /Delete [/S system [/U username [/P [password]]]]
    #          /TN taskname [/F] [/HRESULT] [/?]
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/Delete", "/S", "localhost", "/TN", "`"$TaskName`"", "/F" );
}

Function Stop-ScheduledTask($TaskName) {
    # SCHTASKS /End [/S system [/U username [/P [password]]]]
    #          /TN taskname [/HRESULT] [/?]
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/End", "/S", "localhost", "/TN", "`"$TaskName`"" );
}

Function Start-ScheduledTask($TaskName) {
    # SCHTASKS /Run [/S system [/U username [/P [password]]]] [/I]
    #          /TN taskname [/HRESULT] [/?]
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/Run", "/S", "localhost", "/TN", "`"$TaskName`"" );
}

Function Enable-ScheduledTask($TaskName) {
    # SCHTASKS /Change [/S system [/U username [/P [password]]]] /TN taskname
    #      { [/RU runasuser] [/RP runaspassword] [/TR taskrun] [/ST starttime]
    #        [/RI interval] [ {/ET endtime | /DU duration} [/K] ]
    #        [/SD startdate] [/ED enddate] [/ENABLE | /DISABLE] [/IT] [/Z] }
    #        [/HRESULT] [/?]
    Invoke-CommandLine -FilePath     "$($env:SystemRoot)\System32\schtasks.exe" `
                       -ArgumentList @( "/Change", "/S", "localhost", "/TN", "`"$TaskName`"", "/ENABLE" );
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
        [string[]] $ArgumentList = @( ),
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

    if( $OctopusParameters.ContainsKey("RunWithElevatedPermissions") )
    {
        $runWithElevatedPermissions = [boolean]::Parse($OctopusParameters['RunWithElevatedPermissions'])
    }
    else
    {
        $runWithElevatedPermissions = $false;
    }

    $days = $OctopusParameters['Days']
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

    Create-ScheduledTask $taskName $runAsUser $runAsPassword $command $arguments $schedule $startTime $startDate $runWithElevatedPermissions $days $interval $duration
    Write-Output "Successfully Created $taskName"
    Enable-ScheduledTask($taskName)
    Write-Output "$taskName enabled"

}


# only execute the step if it's called from octopus deploy,
# and skip it if we're runnning inside a Pester test
if( Test-Path -Path "Variable:OctopusParameters" )
{
    Invoke-OctopusStep -OctopusParameters $OctopusParameters;
}
