# Initialize variables
$connectionString = ""
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection

# Determine authentication method
switch ($createAuthenticationMethod)
{
	"AzureADManaged"
    {
    	Write-Host "Using Azure Managed Identity authentication ..."
        $connectionString = "Server=$createSqlServer;Database=master;"
        
        $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fdatabase.windows.net%2F' -Method GET -Headers @{Metadata="true"} -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        $AccessToken = $content.access_token
        
        $sqlConnection.AccessToken = $AccessToken
        break
    }
    "SqlAuthentication"
    {
    	Write-Host "Using Sql account authentication ..."
        $connectionString = "Server=$createSqlServer;Database=master;User ID=$createSqlLoginUserWhoHasCreateUserRights;Password=$createSqlLoginPasswordWhoHasRights;"
        break
    }
    "WindowsIntegrated"
    {
    	Write-Host "Using Windows Integrated authentication ..."
        $connectionString = "Server=$createSqlServer;Database=master;integrated security=true;"
        break
    }
}


$sqlConnection.ConnectionString = $connectionString

$command = $sqlConnection.CreateCommand()
$command.CommandType = [System.Data.CommandType]'Text'
$command.CommandTimeout = $createCommandTimeout

Write-Host "Opening the connection to $createSqlServer"
$sqlConnection.Open()

$escapedDatabaseName = $createDatabaseName.Replace("'", "''")

Write-Host "Running the if not exists then create for $createDatabaseName"
$command.CommandText = "IF NOT EXISTS (select Name from sys.databases where Name = '$escapedDatabaseName')
        create database [$createDatabaseName]"
        
if (![string]::IsNullOrWhiteSpace($createAzureEdition))
{
	Write-Verbose "Specifying Azure SqlDb Edition: $($createAzureEdition)"
	$command.CommandText += ("`r`n (EDITION = '{0}')" -f $createAzureEdition)
}

if (![string]::IsNullOrWhiteSpace($createAzureBackupStorageRedundancy))
{
	Write-Verbose "Specifying Azure Backup storage redundancy: $($createAzureBackupStorageRedundancy)"
	$command.CommandText += ("`r`n WITH BACKUP_STORAGE_REDUNDANCY='{0}'" -f $createAzureBackupStorageRedundancy)
}

$command.CommandText += ";"

$command.ExecuteNonQuery()

Write-Host "Successfully created the account $createDatabaseName"
Write-Host "Closing the connection to $createSqlServer"
$sqlConnection.Close()