$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

Describe "Create-ScheduledTask" {

    Mock -CommandName "Invoke-CommandLine" `
         -MockWith    { };


	Context "No parameters specified" {
        It "Should invoke a matching command line" {
            Create-ScheduledTask;
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "C:\Windows\System32\schtasks.exe"
                $expectedArgs = @( "/create", "/tn", "", "/tr", "''", "/ru", "", "/rp", "", "/sc", "", "/f" )
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
			                     -Duration      "" `
			                     -Interval      "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "C:\Windows\System32\schtasks.exe"
                $expectedArgs = @( "/create", "/tn", "", "/tr", "''", "/ru", "", "/rp", "", "/sc", "", "/f" )
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
			                     -Duration      "myDuration" `
			                     -Interval      "myInterval";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "C:\Windows\System32\schtasks.exe"
                $expectedArgs = @( "/create", "/tn", "myTaskname", "/tr", "`"'myTaskRun' 'myArguments'`"", "/ru", "myRunAsUser", "/rp", "myRunAsPassword", "/sc", "mySchedule", "/sd", "myStartDate", "/st", "myStartTime", "/du", "myDuration", "/rl", "HIGHEST", "/d", "myDays", "/f" )
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
			                     -Duration      "" `
			                     -Interval      "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "C:\Windows\System32\schtasks.exe"
                $expectedArgs = @( "/create", "/tn", "", "/tr", "'myTaskRun'", "/ru", "", "/rp", "", "/sc", "", "/f" )
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
			                     -Duration      "" `
			                     -Interval      "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "C:\Windows\System32\schtasks.exe"
                $expectedArgs = @( "/create", "/tn", "", "/tr", "`"'myTaskRun' 'myArguments'`"", "/ru", "", "/rp", "", "/sc", "", "/f" )
				$argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                #Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                #Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                #Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
			}
        }
    }

	Context "WEEKDAYS schedule parameter specified" {
        It "Should invoke a matching command line" {
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
			                     -Duration      "" `
			                     -Interval      "";
            Assert-MockCalled Invoke-CommandLine -Times 1 -ParameterFilter {
                $expectedCmd  = "C:\Windows\System32\schtasks.exe"
                $expectedArgs = @( "/create", "/tn", "", "/tr", "''", "/ru", "", "/rp", "", "/sc", "WEEKLY", "/d", "MON,TUE,WED,THU,FRI", "/f" )
				$argDiffs     = Compare-Object $ArgumentList $expectedArgs -SyncWindow 0;
                Write-Host ("expected = " + ($expectedArgs | % { "[$($_)]"}));
                Write-Host ("actual   = " + ($ArgumentList | % { "[$($_)]"}));
                Write-Host ($argDiffs | ft | out-string);
                return ($FilePath -eq $expectedCmd) -and ($argDiffs -eq $null);
			}
        }
    }

}