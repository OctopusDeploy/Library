Write-Host "SqlLoginWhoHasRights $createSqlLoginUserWhoHasCreateUserRights"
Write-Host "CreateSqlServer $createSqlServer"
Write-Host "CreateDatabaseName $createDatabaseName"
Write-Host "CreateSqlLogin $createSqlLogin"

if ([string]::IsNullOrWhiteSpace($createSqlLoginUserWhoHasCreateUserRights) -eq $true){
	Write-Host "No username found, using integrated security"
    $connectionString = "Server=$createSqlServer;Database=$createDatabaseName;integrated security=true;"
}
else {
	Write-Host "Username found, using SQL Authentication"
    $connectionString = "Server=$createSqlServer;Database=$createDatabaseName;User ID=$createSqlLoginUserWhoHasCreateUserRights;Password=$createSqlLoginPasswordWhoHasRights;"
}

$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString

$command = $sqlConnection.CreateCommand()
$command.CommandType = [System.Data.CommandType]'Text'

Write-Host "Opening the connection to $createSqlServer"
$sqlConnection.Open()

$escapedSqlLogin = $createSqlLogin.Replace("'", "''")

Write-Host "Running the if not exists then create for $createSqlLogin"
$command.CommandText = "If Not Exists (select 1 from sysusers where name = '$escapedSqlLogin')
	CREATE USER [$createSqlLogin] FOR LOGIN [$createSqlLogin] WITH DEFAULT_SCHEMA=[dbo]"            
$command.ExecuteNonQuery()

Write-Host "Successfully created the account $createSqlLogin"
Write-Host "Closing the connection to $createSqlServer"
$sqlConnection.Close()