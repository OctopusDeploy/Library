if ([string]::IsNullOrWhiteSpace($createSqlLoginUserWhoHasCreateUserRights) -eq $true) {
    Write-Output "No username found, using integrated security"
    $connectionString = "Server=$createSqlServer;Database=master;integrated security=true;"
}
else {
    Write-Output "Username found, using SQL Authentication"
    $connectionString = "Server=$createSqlServer;Database=master;User ID=$createSqlLoginUserWhoHasCreateUserRights;Password=$createSqlLoginPasswordWhoHasRights;"
}


function Retry-Command {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$ScriptBlock,
 
        [Parameter(Position = 1, Mandatory = $false)]
        [int]$Maximum = 1,

        [Parameter(Position = 2, Mandatory = $false)]
        [int]$Delay = 100
    )

    Begin {
        $count = 0
    }

    Process {
        $ex = $null
        do {
            $count++
            
            try {
                Write-Verbose "Attempt $count of $Maximum"
                $ScriptBlock.Invoke()
                return
            }
            catch {
                $ex = $_
                Write-Warning "Error occurred executing command (on attempt $count of $Maximum): $($ex.Exception.Message)"
                Start-Sleep -Milliseconds $Delay
            }
        } while ($count -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw "Execution failed (after $count attempts): $($ex.Exception.Message)"
    }
}

[int]$maximum = 0
[int]$delay = 100

if (-not [int]::TryParse($createSqlDatabaseRetryAttempts, [ref]$maximum)) { $maximum = 0 }

# We add 1 here as if retry attempts is 1, this means we make 2 attempts overall
$maximum = $maximum + 1

Retry-Command -Maximum $maximum -Delay $delay -ScriptBlock {
	
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $connectionString
    try {
        
        $command = $sqlConnection.CreateCommand()
        $command.CommandType = [System.Data.CommandType]'Text'
        $command.CommandTimeout = $createCommandTimeout

        Write-Output "Opening the connection to $createSqlServer"
        $sqlConnection.Open()

        $escapedDatabaseName = $createDatabaseName.Replace("'", "''")

        Write-Output "Running the if not exists then create for $createDatabaseName"
        $command.CommandText = "IF NOT EXISTS (select Name from sys.databases where Name = '$escapedDatabaseName')
        create database [$createDatabaseName]"
        
        if (![string]::IsNullOrWhiteSpace($createAzureEdition)) {
            Write-Verbose "Specifying Azure SqlDb Edition: $($createAzureEdition)"
            $command.CommandText += ("`r`n (EDITION = '{0}')" -f $createAzureEdition)
        }

        if (![string]::IsNullOrWhiteSpace($createAzureBackupStorageRedundancy)) {
            Write-Verbose "Specifying Azure Backup storage redundancy: $($createAzureBackupStorageRedundancy)"
            $command.CommandText += ("`r`n WITH BACKUP_STORAGE_REDUNDANCY='{0}'" -f $createAzureBackupStorageRedundancy)
        }

        $command.CommandText += ";"

        $result = $command.ExecuteNonQuery()
        Write-Verbose "ExecuteNonQuery result: $result"

        Write-Output "Successfully executed the database creation script for $createDatabaseName"
    }

    finally {
        if ($null -ne $sqlConnection) {
            Write-Output "Closing the connection to $createSqlServer"
            $sqlConnection.Dispose()
        }
    }
}