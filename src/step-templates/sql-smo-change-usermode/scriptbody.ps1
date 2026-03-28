[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

$SqlUsername = $OctopusParameters['SqlUsername']
$SqlServer = $OctopusParameters['SqlServer']
$SqlPassword = $OctopusParameters['SqlPassword']
$SqlDatabase = $OctopusParameters['SqlDatabase']
$UserAccess = $OctopusParameters['UserAccess']
$Condition = $OctopusParameters['Condition']

try
{    
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SqlServer
  
    if ($SqlUsername -and $SqlPassword)
    {
        Write-Host "Connecting to $SqlServer as $SqlUsername"
        $server.ConnectionContext.LoginSecure = $false
        $server.ConnectionContext.set_Login($SqlUsername)
        $server.ConnectionContext.set_Password($SqlPassword)      
    } 
    else {
        Write-Host "Connecting to $SqlServer with integrated security"
        $server.ConnectionContext.LoginSecure = $true
    }
    
    $db = $server.Databases[$SqlDatabase]
	if ($db -eq $null)
	{
        Write-Host "Database $SqlDatabase not found, skipping step..."
	} else {
	    Write-Host "Setting user mode to $UserAccess for database $SqlDatabase with condition $Condition"
        $db.UserAccess = $UserAccess

        if ($Condition -eq 'Force'){
            $db.Alter([Microsoft.SqlServer.Management.Smo.TerminationClause]::RollbackTransactionsImmediately)
        } elseif ($Condition -eq 'Fail'){
            $db.Alter([Microsoft.SqlServer.Management.Smo.TerminationClause]::FailOnOpenTransactions)
        } else {
            $db.Alter()
        }
	}
}
catch
{    
    $error[0] | format-list -force
    Exit 1
}