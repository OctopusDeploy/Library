[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

try
{
    $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SMO_SqlServer
    
    $server.ConnectionContext.LoginSecure = $true

    if(!$server.Databases.Contains($SMO_SqlDatabase))
    {
        throw "Server $SMO_SqlServer does not contain a database named $SMO_SqlDatabase"
    }

    if ($server.Logins.Contains($SMO_LoginName))
    {
        Write-Host "Login $SMO_LoginName already exists in the server $SMO_SqlServer"
    }
    else
    {
        Write-Host "Login $SMO_LoginName does not exist, creating"
        $login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $SMO_SqlServer, $SMO_LoginName
        $login.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::WindowsUser
        $login.PasswordExpirationEnabled = $false
        $login.Create()
        Write-Host "Login $SMO_LoginName created successfully."
    }

    $database = $server.Databases[$SMO_SqlDatabase]

    if ($database.Users[$SMO_LoginName])
    {
        Write-Host "User $SMO_LoginName already exists in the database $SMO_SqlDatabase"
    }
    else
    {
        Write-Host "User $SMO_LoginName does not exist in the database $SMO_SqlDatabase, creating."
        $dbUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.User -ArgumentList $database, $SMO_LoginName
        $dbUser.Login = $SMO_LoginName
        $dbUser.Create()
        Write-Host "User $SMO_LoginName created successfully in the database $SMO_SqlDatabase."
    }

    if($SMO_SqlRole -ne $null)
    {
        $SMO_SqlRoles = $SMO_SqlRole.Split(",")
            
        # Remove the user from any roles which aren't specified in the $SMO_SqlRole parameter if they are a member
        $database.Users[$SMO_LoginName].EnumRoles() | ForEach {
            if (!$SMO_SqlRoles.Contains($_)) {
                $dbRole = $database.Roles[$_]
                $dbRole.DropMember($SMO_LoginName)
                $dbRole.Alter()
                Write-Host "User $SMO_LoginName removed from $_ role in the database $SMO_SqlDatabase."
            }
        }
            
        # Add the user to any roles which are specified in the $SMO_SqlRole parameter if they are not already a member
        $SMO_SqlRoles | ForEach {
            $dbRole = $database.Roles[$_]
            if(!$dbRole)  { throw "Database $SMO_SqlDatabase does not contain a role named $_" }

            if (!$dbRole.EnumMembers().Contains($SMO_LoginName))
            {
                $dbRole.AddMember($SMO_LoginName)
                $dbRole.Alter()
                Write-Host "User $SMO_LoginName successfully added to $_ role in the database $SMO_SqlDatabase."
            }
        }
    }
}
catch
{
    $error[0] | format-list -force
    Exit 1
}