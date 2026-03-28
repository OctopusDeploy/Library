$command = "$env:windir\Microsoft.NET\$FrameworkDirectory\aspnet_regsql.exe"
$params = @('-ssadd', '-sstype', 'p', '-S', $SqlServer)
try
{    
    if ($SqlUsername -ne $null -and $SqlPassword -ne $null)
    {
        $params += @('-U', $SqlUsername, '-P', $SqlPassword)
    } else {
        $params += @('-E')
    }
    
    & $command @params
}
catch
{    
    $error[0] | format-list -force
    Exit 1
}