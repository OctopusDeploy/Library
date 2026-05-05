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

Write-Host "Running the script to add the user $createSqlLogin to the role $createRoleName"
$command.CommandText = "ALTER ROLE [$createRoleName] ADD MEMBER [$createSqlLogin]"            
$command.ExecuteNonQuery()

Write-Host "Successfully ran the script to add the user $createSqlLogin to the role $createRoleName"
Write-Host "Closing the connection to $createSqlServer"
$sqlConnection.Close()