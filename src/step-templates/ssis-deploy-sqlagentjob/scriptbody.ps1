Function Format-OctopusArgument
{

    <#
    .SYNOPSIS
    Converts boolean values to boolean types

    .DESCRIPTION
    Converts boolean values to boolean types

    .PARAMETER Value
    The value to convert

    .EXAMPLE
    Format-OctopusArgument "true"
    #>
    Param(
        [string]$Value
    )

    $Value = $Value.Trim()

    # There must be a better way to do this
    Switch -Wildcard ($Value)
    {

        "True"
        { Return $True
        }
        "False"
        { Return $False
        }
        "#{*}"
        { Return $null
        }
        Default
        { Return $Value
        }
    }
}


Function Get-SSISCommand
{

    <#
    .SYNOPSIS
    Format the SSIS Command that execute the package.
    Only valid for now for Project Deployment ($typecommand = '/ISSERVER "\')

    .DESCRIPTION
    Return a string with the correct format to execute a Project Package Deploy (Step).
    The SSIS Command can be built by paramaters (ServerName, CatalogName, ProjectName, FolderName, Package and Environment)
    @TO-DO:
    But most of the cases need an ending string that could be the same for most of the deployments.
    I will keep this as a Octopus Parameter by now.


    #>

    Param($ServerName, $CatalogName, $FolderName, $ProjectName, $PackageName, $EnvironmentName)
    process {
        $environmentid = Get-EnvironmentId -ServerName $ServerName -EnvironmentName $EnvironmentName -PackageName $PackageName -ProjectName $ProjectName
        write-host "The Environmemnt Id found for $EnvironmentName is $environmentid"
        $slash = '\'
        $quotes = '"'
        $typecommand = '/ISSERVER "\'
        $environmentCommand = '\"" /ENVREFERENCE ' + $environmentid.ToString()
        $packagep = $slash + $CatalogName + $slash + $FolderName + $slash + $ProjectName + $slash + $PackageName + '.dtsx' + $slash
        $servertype = '" /SERVER "\"'
        $commandoptions = ' /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E'
    }
    end {
        return $typecommand + $quotes + $packagep + $quotes + $servertype + $ServerName + $environmentCommand + $commandoptions
    }

}

Function Get-EnvironmentId
{
    <#
    .SYNOPSIS
    Get the ID of the Environment by Name of Environment

    .DESCRIPTION
    ProjectDeploy Packages use Enviroments for variables previously deployed for the package.
    To be able to format the SSIS Command, we will need the Environment ID

    .PARAMETER ServerName
    .PARAMETER CatalogName
    .PARAMETER FolderName
    .PARAMETER ProjectName
    .PARAMETER PackageName
    .PARAMETER EnvironmentName
    #>

    Param($ServerName, $EnvironmentName,$PackageName, $ProjectName)


    $query = "SELECT er.reference_id
    FROM [SSISDB].[internal].[folders] AS f
         JOIN [SSISDB].[internal].[projects] AS p
              ON f.folder_id = p.folder_id
              JOIN [SSISDB].[internal].[environment_references] AS er
                   ON p.project_id = er.project_id
                   where f.name = '$FolderName'
						and er.environment_name = '$EnvironmentName'
						 and p.name = '$ProjectName'"

    $EnvironmentId = Invoke-Sqlcmd  -Query $query -ServerInstance $ServerName -Verbose

    return $EnvironmentId.reference_id
}

Function Add-Job
{
    <#
    .SYNOPSIS
    Add a new type of Job in SQL Agent Job

    .DESCRIPTION
    The function will remove an existing Job with same name (SQL SMO Job doesnt contains update function)
    and it will return as GlobalVariable the JOb Object.

    .PARAMETER JobName
    .PARAMETER ServerName
    .PARAMETER EnvironmentName
    .PARAMETER JobStepName
    .PARAMETER JobStepCommand
    #>

    param($JobName, $ServerName, $EnvironmentName, $JobsStepName, $JobStepCommand, $JobCategory )
    try
    {
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerName)
        $server.exe
        $server.JobServer.HostLoginName
        $existingjob = $server.Jobserver.Jobs|where-object {$_.Name -like $JobName}
        if ($existingjob)
        {
            Write-Host "|- Dropping Job [$JobName]..." -NoNewline
            $existingjob.drop()
            Write-Host "|- Done" -ForegroundColor Green
        }

        $job = New-Object Microsoft.SqlServer.Management.SMO.Agent.Job($server.JobServer, $jobName)
        #$job.DropIfExists() only for sqlserver 2016
        $job.Create()
        $job.OwnerLoginName = "sa"
        $job.Category = $JobCategory
        $job.ApplyToTargetServer($server.Name)


    }
    catch
    {
        write-host "####### Error Adding a job" -ForegroundColor Red
        write-host $_.Exception.Message
    }
    #Instead of creating a class and return a Job, lets settup a global variable. Return statament doenst return all script output
    $Global:newjob = $job

}

Function Add-JobStep
{
    <#
    .SYNOPSIS
    Add a job step to a Job

    .DESCRIPTION
    The function will remove an existing Job with same name (SQL SMO Job doesnt contains update function)
    and it will return as GlobalVariable t
     he JOb Object.
    .PARAMETER Job
    .PARAMETER JobStepName
    .PARAMETER JobStepCommand
    #>
    param($job, $JobStepName, $CommandJob )
    try
    {
        $jobStep = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobStep($job, $JobStepName)
        $jobStep.Subsystem = [Microsoft.SqlServer.Management.Smo.Agent.AgentSubSystem]::SSIS

        $jobStep.Command = $CommandJob
        $jobStep.Create()
    }
    catch
    {
        write-host "#########   Error adding a job step" -ForegroundColor Red
        write-host $_.Exception.Message
    }


}

Function Add-JobSchedule
{
    # ToDO: Add more types of frequenct: Weekly, Monthly
    param($job, $JobScheduleName,$JobExecutionFrequency, $FrecuencyInterval, $startHour, $startMinutes)
    try
    {
        $name = $job.Name
        $SQLJobSchedule = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobSchedule($job, $JobScheduleName)

        switch ($JobExecutionFrequency) {
            "Daily" {
                     $result = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily
                     $subdayTypes =  [Microsoft.SqlServer.Management.SMO.Agent.FrequencySubDayTypes]::Hour
                    }
            "OneTime" {
                 $result = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::OneTime
                 $subdayTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencySubDayTypes]::Once
                 }
            "AutoStart" {
                    $result = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::AutoStart
                   }
            default  {
                $result = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily
              }
        }


        $SQLJobSchedule.FrequencyTypes =  $result
        # Setup Frequency Interval
        $SQLJobSchedule.FrequencyInterval = $FrecuencyInterval



        # Job Start
        $timeofday = New-TimeSpan -hours $startHour -minutes $startMinutes
        $SQLJobSchedule.ActiveStartTimeOfDay = $timeofday
        #Activate the Job
        $SQLJobSchedule.ActiveStartDate = Get-Date
        $SQLJobSchedule.Create()
    }
    catch
    {
        Write-Host "Error" -ForegroundColor Red
        write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        $error[0]|format-list -force

    }

}

Function Set-SQLJob
{
    #Get-Octopus Variables
    Write-Host "Collecting Octopus Variables"

    $ServerName = Format-OctopusArgument -Value $OctopusParameters["SSIS_ServerName"]
    $FolderName = Format-OctopusArgument -Value $OctopusParameters["SSIS_FolderName"]
    $ProjectName = Format-OctopusArgument -Value $OctopusParameters["SSIS_ProjectName"]
    $CatalogName = Format-OctopusArgument -Value $OctopusParameters["SSIS_CatalogName"]
    $EnvironmentName = Format-OctopusArgument -Value $OctopusParameters["SSIS_EnvironmentName"]
    $PackageName = Format-OctopusArgument -Value $OctopusParameters["SSIS_PackageName"]
    $JobName = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobName"]
    $JobCategory =  Format-OctopusArgument -Value $OctopusParameters["SSIS_JobCategory"]
    $JobStepName = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobStepName"]
    $JobScheduleName = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobScheduleName"]
    $JobExecutionFrequency = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobExecutionFrequency"]
    $JobFrequencyInterval = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobFrequencyInterval"]
    $JobExecutionTimeHour = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobExecutionTimeHour"]
    $JobExecutionTimeMinute = Format-OctopusArgument -Value $OctopusParameters["SSIS_JobExecutionTimeMinute"]


   # FrecuencyType is hardcoded

    #Getting Module sqlserver if possible.
    $Module = get-module -ListAvailable -name sqlserver
    if ($Module.Name -eq 'sqlserver') {
        write-host "Importing Module SqlServer"
        Import-Module sqlserver -DisableNameChecking
    } else {
        write-host "Importing Module sqlps"
        import-module sqlps -Verbose -DisableNameChecking
    }

    #First step is to generate the command execution for Job Step.
    $JobStepCommand = Get-SSISCommand -ServerName $ServerName -CatalogName $CatalogName -FolderName $FolderName -ProjectName $ProjectName -PackageName $PackageName -EnvironmentName $EnvironmentName -Verbose

    write-Host "Command found to deploy Step is "
    write-Host $JobStepCommand
    write-Host "STARTING DEPLOYMENT "
    write-Host "|- Start Adding the Job $JobName"
    Add-Job -JobName $JobName -ServerName $ServerName -EnvironmentName $EnvironmentName -JobsStepName $JobStepName -JobStepCommand $JobStepCommandmand
    write-Host "|- $JobName Added to $ServerName"

    write-Host "|--- Start Adding the JobStep $JobStepName to Job $JobName"
    Add-JobStep -JobStepName $JobStepName -CommandJob $JobStepCommand -Job $Global:newjob
    write-Host "|--- $JobStepName added to Job $JobName"

    write-Host "|----  Start Adding JobShedule  $JobScheduleName JobStep $JobName"
    Add-JobSchedule -job $Global:newjob  -JobScheduleName $JobScheduleName  -JobExecutionFrequency $JobExecutionFrequency -FrecuencyInterval $JobFrequencyInterval -startHour $JobExecutionTimeHour -startMinutes $JobExecutionTimeMinute
    write-Host "|---- $JobStepName added to Job $JobName"
}

Write-Host "Starting deployment of SQL Job"


Set-SQLJob


Write-Host "Finishing Install"
