$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

. (Join-Path $PSScriptRoot ".." "windows-scheduled-task-create.ScriptBody.ps1")

Describe "Create-ScheduledTask" {

    Mock -CommandName "Invoke-CommandLine" `
         -MockWith    { };

    Context "No parameters specified" {
        It "Should invoke a matching command line" {
            Create-ScheduledTask;
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "$($env:SystemRoot)\System32\schtasks.exe"
                $expectedArgs = @( "/Create", "/RU", "`"`"", "/SC", "", "/TN", "`"`"", "/TR", "`"''`"", "/F" )
                $argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                #Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                #Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                #Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
            }
        }
    }

    Context "All parameters are empty strings" {
        It "Should invoke a matching command line" {
            Create-ScheduledTask -TaskName      "" `
                                 -RunAsUser     "" `
                                 -RunAsPassword "" `
                                 -TaskRun       "" `
                                 -Arguments     "" `
                                 -Schedule      "" `
                                 -StartTime     "" `
                                 -StartDate     "" `
                                 -RunWithElevatedPermissions "" `
                                 -Days          "" `
                                 -Interval      "" `
                                 -Duration      "" `
                                 -StartNewTaskNow "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "$($env:SystemRoot)\System32\schtasks.exe"
                $expectedArgs = @( "/Create", "/RU", "`"`"", "/SC", "", "/TN", "`"`"", "/TR", "`"''`"", "/F" )
                $argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                #Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                #Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                #Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
            }
        }
    }

    Context "All parameters are specified" {
        It "Should invoke a matching command line" {
            Create-ScheduledTask -TaskName      "myTaskName" `
                                 -RunAsUser     "myRunAsUser" `
                                 -RunAsPassword "myRunAsPassword" `
                                 -TaskRun       "myTaskRun" `
                                 -Arguments     "myArguments" `
                                 -Schedule      "mySchedule" `
                                 -StartTime     "myStartTime" `
                                 -StartDate     "myStartDate" `
                                 -RunWithElevatedPermissions "myRunWithElevatedPermissions" `
                                 -Days          "myDays" `
                                 -Interval      "myInterval" `
                                 -Duration      "myDuration"`
                                 -StartNewTaskNow "myStartNewTaskNow";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "$($env:SystemRoot)\System32\schtasks.exe"
                $expectedArgs = @( "/Create", "/RU", "`"myRunAsUser`"", "/RP `"myRunAsPassword`"", "/SC", "mySchedule", "/RI", "myInterval", "/D", "myDays", "/TN", "`"myTaskName`"", "/TR", "`"'myTaskRun' myArguments`"", "/ST", "myStartTime", "/DU", "myDuration", "/SD", "myStartDate", "/F", "/RL", "HIGHEST" )
                $argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                #Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                #Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                #Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
            }
        }
    }

    Context "Task specified with no arguments" {
        It "Should invoke a matching command line" {
            Create-ScheduledTask -TaskName      "" `
                                 -RunAsUser     "" `
                                 -RunAsPassword "" `
                                 -TaskRun       "myTaskRun" `
                                 -Arguments     "" `
                                 -Schedule      "" `
                                 -StartTime     "" `
                                 -StartDate     "" `
                                 -RunWithElevatedPermissions "" `
                                 -Days          "" `
                                 -Interval      "" `
                                 -Duration      "" `
                                 -StartNewTaskNow "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "$($env:SystemRoot)\System32\schtasks.exe"
                $expectedArgs = @( "/Create", "/RU", "`"`"", "/SC", "", "/TN", "`"`"", "/TR", "`"'myTaskRun'`"", "/F" )
                $argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                #Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                #Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                #Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
            }
        }
    }

    Context "Task specified with arguments" {
        It "Should invoke a matching command line" {
            Create-ScheduledTask -TaskName      "" `
                                 -RunAsUser     "" `
                                 -RunAsPassword "" `
                                 -TaskRun       "myTaskRun" `
                                 -Arguments     "myArguments" `
                                 -Schedule      "" `
                                 -StartTime     "" `
                                 -StartDate     "" `
                                 -RunWithElevatedPermissions "" `
                                 -Days          "" `
                                 -Interval      "" `
                                 -Duration      "" `
                                 -StartNewTaskNow "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "$($env:SystemRoot)\System32\schtasks.exe"
                $expectedArgs = @( "/Create", "/RU", "`"`"", "/SC", "", "/TN", "`"`"", "/TR", "`"'myTaskRun' myArguments`"", "/F" )
                $argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                #Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                #Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                #Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
            }
        }
    }

    Context "WEEKDAYS schedule parameter specified" {
        It "WEEKDAYS is passed through when no days are specified" {
            Create-ScheduledTask -TaskName      "" `
                                 -RunAsUser     "" `
                                 -RunAsPassword "" `
                                 -TaskRun       "" `
                                 -Arguments     "" `
                                 -Schedule      "WEEKDAYS" `
                                 -StartTime     "" `
                                 -StartDate     "" `
                                 -RunWithElevatedPermissions "" `
                                 -Days          "" `
                                 -Interval      "" `
                                 -Duration      "" `
                                 -StartNewTaskNow "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "$($env:SystemRoot)\System32\schtasks.exe"
                $expectedArgs = @( "/Create", "/RU", "`"`"", "/SC", "WEEKDAYS", "/TN", "`"`"", "/TR", "`"''`"", "/F" )
                $argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
            }
        }
    }

}
