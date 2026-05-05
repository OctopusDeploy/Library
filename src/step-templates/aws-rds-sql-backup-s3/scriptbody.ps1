Write-Host "SqlLoginWhoHasRights $rdsSqlBackupSqlLoginUserWhoHasCreateUserRights"
Write-Host "CreateSqlServer $rdsSqlBackupSqlServer"
Write-Host "CreateDatabaseName $rdsSqlBackupDatabaseName"
Write-Host "Backup S3 Bucket $rdsSqlBackupS3Bucket"
Write-Host "Backup File Name $rdsSqlBackupFileName"

if ([string]::IsNullOrWhiteSpace($rdsSqlBackupSqlLoginUserWhoHasCreateUserRights) -eq $true){
	Write-Host "No username found, using integrated security"
    $connectionString = "Server=$rdsSqlBackupSqlServer;Database=msdb;integrated security=true;"
}
else {
	Write-Host "Username found, using SQL Authentication"
    $connectionString = "Server=$rdsSqlBackupSqlServer;Database=msdb;User ID=$rdsSqlBackupSqlLoginUserWhoHasCreateUserRights;Password=$rdsSqlBackupSqlLoginPasswordWhoHasRights;"
}

$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString

$command = New-Object System.Data.SqlClient.SqlCommand("dbo.rds_backup_database", $sqlConnection)
$command.CommandType = [System.Data.CommandType]'StoredProcedure'

$backupDestParamValue = "arn:aws:s3:::$rdsSqlBackupS3Bucket/$rdsSqlBackupFileName"
$command.Parameters.AddWithValue("s3_arn_to_backup_to", $backupDestParamValue)
$command.Parameters.AddWithValue("overwrite_S3_backup_file", 1)
$command.Parameters.AddWithValue("source_db_name", $rdsSqlBackupDatabaseName)

$taskStatusCommand = New-Object System.Data.SqlClient.SqlCommand("dbo.rds_task_status", $sqlConnection)
$taskStatusCommand.CommandType = [System.Data.CommandType]'StoredProcedure'
$taskStatusCommand.Parameters.AddWithValue("db_name", $rdsSqlBackupDatabaseName)

$taskStatusAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $taskStatusCommand

Write-Host "Opening the connection to $rdsSqlBackupSqlServer"
$sqlConnection.Open()
    
Write-Host "Executing backup"
$command.ExecuteNonQuery()

Write-Host "Closing the connection to $rdsSqlBackupSqlServer"
$sqlConnection.Close()

Write-Host "Getting status of backup"
$backupIsActive = $true

While ($backupIsActive)
{
	Write-Host "Opening the connection to $rdsSqlBackupSqlServer"
	$sqlConnection.Open()
    
    $taskStatusDataSet = New-Object System.Data.DataSet
	$taskStatusAdapter.Fill($taskStatusDataSet)
    $taskStatus = $taskStatusDataSet.Tables[0].Rows[0]["lifecycle"]
    $taskComplete = $taskStatusDataSet.Tables[0].Rows[0]["% complete"]
    
    Write-Host "The task is $taskComplete% complete."
    $backupIsActive = $taskStatus -eq "CREATED" -or $taskStatus -eq "IN_PROGRESS"
    
    Write-Host "Closing the connection to $rdsSqlBackupSqlServer"
	$sqlConnection.Close()
    
    Start-Sleep -Seconds 5
}