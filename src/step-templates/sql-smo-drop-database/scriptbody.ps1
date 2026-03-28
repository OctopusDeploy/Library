[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

try
{    
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SqlServer
    
    if (!$SqlUsername -and !$SqlPassword)
    {
        $server.ConnectionContext.LoginSecure = $true
    } else {
        $server.ConnectionContext.LoginSecure = $false
        $server.ConnectionContext.set_Login($SqlUsername)
        $server.ConnectionContext.set_Password($SqlPassword)      
    }

	if ($server.databases[$SqlDatabase] -ne $null)
	{
    	$server.killallprocesses($SqlDatabase)
    	$server.databases[$SqlDatabase].drop()
	}
}
catch
{    
    $error[0] | format-list -force
    Exit 1
}
    