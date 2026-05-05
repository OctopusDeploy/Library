if ([string]::IsNullOrWhiteSpace($createSqlLoginUserWhoHasCreateUserRights) -eq $true){
	Write-Host "No username found, using integrated security"
    $connectionString = "Server=$createSqlServer;Database=master;integrated security=true;"
}
else {
	Write-Host "Username found, using SQL Authentication"
    $connectionString = "Server=$createSqlServer;Database=master;User ID=$createSqlLoginUserWhoHasCreateUserRights;Password=$createSqlLoginPasswordWhoHasRights;"
}

$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString

$command = $sqlConnection.CreateCommand()
$command.CommandType = [System.Data.CommandType]'Text'

Write-Host "Opening the connection to $createSqlServer"
$sqlConnection.Open()

$escapedDatabaseName = $deleteDatabaseName.Replace("'", "''")

Write-Host "Running the if exists then delete for $createDatabaseName"
$command.CommandText = "IF EXISTS (select Name from sys.databases where Name = '$escapedDatabaseName')
        drop database [$deleteDatabaseName]"            
$command.ExecuteNonQuery()


Write-Host "Successfully dropped the database $createDatabaseName"
Write-Host "Closing the connection to $createSqlServer"
$sqlConnection.Close()