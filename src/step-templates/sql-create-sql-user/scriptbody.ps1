Function Test-AzureSQL
{
	# Define parameters
    param ($SqlConnection)
    
    # Define local variables
    $azureDetected = $false
    
    # Create command object
    $command = $SqlConnection.CreateCommand()

    # Check state
    if ($SqlConnection.State -ne [System.Data.ConnectionState]::Open)
    {
    	# Open the connection
        $SqlConnection.Open()
    }
    
    # Set command text
    $command.CommandType = [System.Data.CommandType]::Text
    $command.CommandText = "SELECT SERVERPROPERTY ('edition')"
    
    # Execute statement
    $reader = $command.ExecuteReader()
    
    # Read results
    while ($reader.Read())
    {
    	# Get value from field
        $value = $reader.GetValue(0)
        
        # Check to see if it's Azure
        if ($value -like "*Azure*")
        {
        	# It's azure
            $azureDetected = $true
            
            # break
            break
        }
    }
    
    # Check to see if reader is open
    if ($reader.IsClosed -eq $false)
    {
    	# Close reader object
        $reader.Close()
    }
    
    # Not found
    return $azureDetected
}

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

$isAzureSQL = Test-AzureSQL -SqlConnection $sqlConnection

$escapedLogin = $createSqlLogin.Replace("'", "''")
Write-Host "Running the if not exists then create user command on the server for $escapedLogin"

if ([string]::IsNullOrWhiteSpace($createSqlPassword) -eq $true) {
	Write-Host "The password sent in was empty, creating account as domain login"
    $command.CommandText = "IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name = '$escapedLogin')
	CREATE LOGIN [$createSqlLogin] FROM WINDOWS"
    
    if ($isAzureSQL -eq $false)
    {
        $command.CommandText += " with default_database=[$createSqlDefaultDatabase]"
    }
    
}
else {
	Write-Host "A password was sent in, creating account as SQL Login"
	$escapedPassword = $createSqlPassword.Replace("'", "''")
	$command.CommandText = "IF NOT EXISTS(SELECT 1 FROM sys.sql_logins WHERE name = '$escapedLogin')
	CREATE LOGIN [$createSqlLogin] with Password='$escapedPassword'"  

    if ($isAzureSQL -eq $false)
    {
        $command.CommandText += ", default_database=[$createSqlDefaultDatabase]"
    }
}


$command.ExecuteNonQuery()

Write-Host "Successfully created the account $createSqlLogin"
Write-Host "Closing the connection to $createSqlServer"
$sqlConnection.Close()