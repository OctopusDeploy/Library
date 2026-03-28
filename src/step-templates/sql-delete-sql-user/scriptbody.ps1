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

$escapedLogin = $deleteSqlLogin.Replace("'", "''")

Write-Host "Running the if not exists then delete user command on the server"
$command.CommandText = "IF EXISTS(SELECT 1 FROM sys.server_principals WHERE name = '$escapedLogin')
	DROP LOGIN [$deleteSqlLogin]"            
$command.ExecuteNonQuery()

Write-Host "Successfully deleted the account $createSqlLogin"
Write-Host "Closing the connection to $createSqlServer"
$sqlConnection.Close()