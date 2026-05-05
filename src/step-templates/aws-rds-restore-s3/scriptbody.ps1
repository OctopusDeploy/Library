Write-Host "SqlLoginWhoHasRights $rdsSqlRestoreBackupSqlLoginUserWhoHasCreateUserRights"
Write-Host "CreateSqlServer $rdsSqlRestoreBackupSqlServer"
Write-Host "CreateDatabaseName $rdsSqlRestoreBackupDatabaseName"
Write-Host "Backup S3 Bucket $rdsSqlRestoreBackupS3Bucket"
Write-Host "Backup File Name $rdsSqlRestoreBackupFileName"

if ([string]::IsNullOrWhiteSpace($rdsSqlRestoreBackupSqlLoginUserWhoHasCreateUserRights) -eq $true){
	Write-Host "No username found, using integrated security"
    $connectionString = "Server=$rdsSqlRestoreBackupSqlServer;Database=msdb;integrated security=true;"
}
else {
	Write-Host "Username found, using SQL Authentication"
    $connectionString = "Server=$rdsSqlRestoreBackupSqlServer;Database=msdb;User ID=$rdsSqlRestoreBackupSqlLoginUserWhoHasCreateUserRights;Password=$rdsSqlRestoreBackupSqlLoginPasswordWhoHasRights;"
}

$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString

$command = New-Object System.Data.SqlClient.SqlCommand("dbo.rds_restore_database", $sqlConnection)
$command.CommandType = [System.Data.CommandType]'StoredProcedure'

$backupDestParamValue = "arn:aws:s3:::$rdsSqlRestoreBackupS3Bucket/$rdsSqlRestoreBackupFileName"
$command.Parameters.AddWithValue("s3_arn_to_restore_from", $backupDestParamValue)
$command.Parameters.AddWithValue("with_norecovery", 0)
$command.Parameters.AddWithValue("restore_db_name", $rdsSqlRestoreBackupDatabaseName)

$taskStatusCommand = New-Object System.Data.SqlClient.SqlCommand("dbo.rds_task_status", $sqlConnection)
$taskStatusCommand.CommandType = [System.Data.CommandType]'StoredProcedure'
$taskStatusCommand.Parameters.AddWithValue("db_name", $rdsSqlRestoreBackupDatabaseName)

$taskStatusAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $taskStatusCommand

Write-Host "Opening the connection to $rdsSqlRestoreBackupSqlServer"
$sqlConnection.Open()
    
Write-Host "Executing backup"
$command.ExecuteNonQuery()

Write-Host "Closing the connection to $rdsSqlRestoreBackupSqlServer"
$sqlConnection.Close()

Write-Host "Getting status of backup"
$backupIsActive = $true

While ($backupIsActive)
{
	Write-Host "Opening the connection to $rdsSqlRestoreBackupSqlServer"
	$sqlConnection.Open()
    
    $taskStatusDataSet = New-Object System.Data.DataSet
	$taskStatusAdapter.Fill($taskStatusDataSet)
    $taskStatus = $taskStatusDataSet.Tables[0].Rows[0]["lifecycle"]
    $taskComplete = $taskStatusDataSet.Tables[0].Rows[0]["% complete"]
    
    Write-Host "The task is $taskComplete% complete."
    $backupIsActive = $taskStatus -eq "CREATED" -or $taskStatus -eq "IN_PROGRESS"
    
    Write-Host "Closing the connection to $rdsSqlRestoreBackupSqlServer"
	$sqlConnection.Close()
    
    Start-Sleep -Seconds 5
}