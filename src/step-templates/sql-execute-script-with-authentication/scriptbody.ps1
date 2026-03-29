function Get-DBConnection
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [string]
        [ValidateNotNullorEmpty()]
        $serverInstance,

        [switch]
        $SqlAuthentication,

        [string]
        $Username,

        [string]
        $Password
    )
    try
    {
        $connection = (New-Object Microsoft.SqlServer.Management.Smo.Server($serverInstance))

        if ($SqlAuthentication)
        {
            $connection.ConnectionContext.LoginSecure = $false
            $connection.ConnectionContext.set_Login($Username)
            $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $connection.ConnectionContext.set_SecurePassword($securePassword)
        }
        
        $connection.Refresh()
        
        return $connection
    }
    catch
    {
        throw $_.Exception.ToString()
    }
        
}

function Invoke-ExecuteSQLScript {

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $serverInstance,

        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $dbName,

        [string]
        $Authentication,

        [string]
        $Username,

        [string]
        $Password,

        [string]
        $SQLScripts
    )

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

    if ($Authentication -eq "SqlAuthentication")
    {
        $SqlServer = Get-DBConnection -serverInstance $serverInstance -SqlAuthentication -Username $Username -Password $Password
    }
    else
    {
        $SqlServer = Get-DBConnection -serverInstance $serverInstance
    }

    if ($null -eq $SqlServer.Databases[$dbName])
    {
        throw "Database $dbName does not exist on server $serverInstance"
    }
    
    if ($null -ne $SqlServer)
    {
        foreach ($SQLScript in $SQLScripts.Split("`n"))
        {
            try 
            {
                $children = $SQLScript -replace ".*\\"
                $replacematch = $children -replace "\*","\*" -replace "\.","\."
                $parent = $SQLScript -replace $replacematch

                $scripts = Get-ChildItem -Path $parent -Filter $children

                foreach ($script in $scripts)
                {
                    $sr = New-Object System.IO.StreamReader($script.FullName)
                    $scriptContent = $sr.ReadToEnd()
                    $SqlServer.Databases[$dbName].ExecuteNonQuery($scriptContent)
                    $sr.Close()

					write-verbose ("Executed manual script - {0}" -f $script.Name)
                }
            }
            catch 
            {
                Write-Error $_.Exception
            }
        }
    }
}

if (Test-Path Variable:OctopusParameters)
{
	if ($null -ne $DacpacPackageExtractStepName -and $DacpacPackageExtractStepName -ne '')
    {
        Write-Verbose "Dacpac Package Extract Step Name not empty. Locating scripts located in the Dacpac Extract Step."
        $installDirPathKey = 'Octopus.Action[{0}].Output.Package.InstallationDirectoryPath' -f $DacpacPackageExtractStepName
        $installDirPath = $OctopusParameters[$installDirPathKey]
        $ScriptsToExecute = Join-Path $installDirPath $SqlScripts
    }
    else
    {   
        Write-Verbose "Locating scripts from the literal entry of Octopus Parameter SQLScripts"
        $ScriptsToExecute = $OctopusParameters["SQLScripts"]
    }
    if ($OctopusParameters["Authentication"] -eq "SqlAuthentication")
    {
        Write-Verbose "Using Sql Authentication"
        Invoke-ExecuteSQLScript -serverInstance $OctopusParameters["serverInstance"] `
                                -dbName $OctopusParameters["dbName"] `
                                -Authentication $OctopusParameters["Authentication"] `
                                -Username $OctopusParameters["Username"] `
                                -Password $OctopusParameters["Password"] `
                                -SQLScripts $ScriptsToExecute
    }
    else
    {
        Write-Verbose "Using Windows Integrated Authentication"
        Invoke-ExecuteSQLScript -serverInstance $OctopusParameters["serverInstance"] `
                                -dbName $OctopusParameters["dbName"] `
                                -SQLScripts $ScriptsToExecute
    }
}