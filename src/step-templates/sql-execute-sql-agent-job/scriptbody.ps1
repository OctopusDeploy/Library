$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $OctopusParameters['ConnectionString']
Register-ObjectEvent -inputobject $connection -eventname InfoMessage -action {
    write-host $event.SourceEventArgs
} | Out-Null

function Run-SqlAgentJob($jobname,$timeout,$stepid) {
	$sqlstring = @"
		SET NOCOUNT ON

		--Declaration
		DECLARE @jobtorun VARCHAR(MAX) = '<JobName>'
		DECLARE @jobid	VARCHAR(50) = ''
		DECLARE @previousid INT
        DECLARE @previous_status INT 
		declare @newid	INT
		DECLARE @runstatus	INT

		CREATE TABLE #results
		(
			instance_id INT,
			job_id	varchar(255),
			job_name VARCHAR(255),
			step_id	INT,
			step_name VARCHAR(255),
			sql_message_id INT,
			sql_severity INT,
			message VARCHAR(MAX),
			run_status INT,
			run_date INT,
			run_time INT,
			run_duration INT,
			operator_emailed VARCHAR(255),
			operator_netsent VARCHAR(255),
			operator_paged VARCHAR(255),
			retries_attempted INT,
			server sysname
		)

		--Get Job ID
		SELECT @jobid = job_id FROM msdb.dbo.sysjobs where name = @jobtorun
		IF @jobid = ''
        BEGIN 
        	RAISERROR ('Job Name Not Found.', -- Message text.
        				16, -- Severity.
        				1 -- State.
        				);
        	RETURN
        END

		--Store previous job history
		INSERT INTO #results
		EXEC sp_help_jobhistory @job_id = @jobid, @mode = 'full', @step_id = <StepId>
        SELECT @previousid = t.instance_id, @previous_status = t.run_status FROM (SELECT TOP 1 instance_id, run_status FROM #results ORDER BY instance_id DESC) t
        PRINT 'Previous job ID: ' + CAST(@previousid AS VARCHAR(5)) + '		Run Status:' + CAST(@previous_status AS VARCHAR(5))
		SET @newid = @previousid

		--Start SQL Agent Job
		EXEC msdb.dbo.sp_start_job @jobtorun

		--Loop for x seconds or until jobhistory has been updated with a new record
		DECLARE @loopct	INT = 1
		WHILE (@newid = @previousid) and (@loopct < <Timeout>)
		BEGIN
			TRUNCATE TABLE #results
			INSERT INTO #results
				EXEC sp_help_jobhistory @job_id = @jobid, @mode = 'full', @step_id = <StepId>

			SELECT @newid = instance_id, @runstatus = run_status FROM #results WHERE instance_id = (SELECT MAX(instance_id) FROM #results)

			PRINT 'Poll ' + CAST(@loopct AS VARCHAR(5)) + '		Time: ' + CONVERT(VARCHAR(8), GETDATE(), 108) 

			SET @loopct += 1
			WAITFOR DELAY '00:00:05'
		END

		IF @newid = @previousid
			RAISERROR ('Job did not complete in time.', -- Message text.
					   16, -- Severity.
					   1 -- State.
					   );
		IF @runstatus <> 1
			RAISERROR ('Job did not complete successfully.', -- Message text.
					   16, -- Severity.
					   1 -- State.
					   );

		PRINT ''
		PRINT 'Time: ' + CONVERT(VARCHAR(8), GETDATE(), 108) + '	New Job ID:' + CAST(@newid AS VARCHAR(5)) + '		Run Status:' + CAST(@runstatus AS VARCHAR(5))

		--Cleanup
		DROP TABLE #results
"@

    $jobname = $jobname -replace "'", "''"
	$sqlstring = $sqlstring -replace "<JobName>", $jobname
	$sqlstring = $sqlstring -replace "<Timeout>", $timeout
	$sqlstring = $sqlstring -replace "<StepId>", $stepid
	
	#Debug Code
	#Write-Host $sqlstring
	
	$command = $connection.CreateCommand()
	$command.CommandText = $sqlstring
	$command.CommandTimeout = 0
	$command.ExecuteNonQuery() | Out-Null
}

Write-Host "Connecting"
try {
    $connection.Open()

    Write-Host "Running SQL Agent Job"
    Run-SqlAgentJob -jobname $OctopusParameters['JobName'] -timeout $OctopusParameters['Timeout'] -step $OctopusParameters['Step']
}
finally {
    Write-Host "Closing connection"
    $connection.Dispose()
}
