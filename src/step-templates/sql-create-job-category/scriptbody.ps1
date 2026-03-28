Write-Host "Running command against database server: $DbServer"
Write-Host "Creating Job category: $JobCatName"
Invoke-Sqlcmd -ServerInstance "$DbServer" -Verbose -Query "EXEC dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'$JobCatName';" -Database "msdb"
Write-Host "Job category created"