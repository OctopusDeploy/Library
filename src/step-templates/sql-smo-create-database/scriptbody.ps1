[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null


$SqlUsername = $OctopusParameters['SqlUsername']
$SqlServer = $OctopusParameters['SqlServer']
$SqlPassword = $OctopusParameters['SqlPassword']
$SqlDatabase = $OctopusParameters['SqlDatabase']

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
    
	if ($server.databases[$SqlDatabase] -eq $null)
	{
	    Write-Host "Creating database $SqlDatabase"
    	$db = New-Object Microsoft.SqlServer.Management.Smo.Database($server, $SqlDatabase)
        $db.Create()
	} else {
	    Write-Host "Database $SqlDatabase already exists, skipping step..."
	}
}
catch
{    
    $error[0] | format-list -force
    Exit 1
}
    