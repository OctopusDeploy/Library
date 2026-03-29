# insure module installed.  Designed to run on cloud infrastructure where owners doesn't have controll over the workers.

if (Get-Module -ListAvailable -Name sqlserver)
{
	Write-Verbose "sqlserver module installed and available"
    Import-Module sqlserver
}

else
{
	Write-Warning "installing module for the current user.`nIf worker is owned, consider installing the powershell module 'sqlserver' globally to speed up deployments"
	Install-Module -Name sqlserver -Scope CurrentUser -AllowClobber -Force
}

# parse parameters

$resourceGroup = $OctopusParameters["azDbSqlCmd.resourceGroupName"]
$sqlServerName = $OctopusParameters["azDbSqlCmd.ServerName"]
$dbName = $OctopusParameters["azDbSqlCmd.dbName"]
$userId = $OctopusParameters["azDbSqlCmd.userId"]
$userPwd = $OctopusParameters["azDbSqlCmd.userPwd"]
$authType = $OctopusParameters["azDbSqlCmd.AuthType"]
$connTimeout = $OctopusParameters["azDbSqlCmd.connectionTimeout"] -as [int]
$resultsOutput = $OctopusParameters["azDbSqlCmd.resultsOutput"]

$sqlCmd = $OctopusParameters["azDbSqlCmd.sqlCmd"]

# get current IP address
Write-Host "Getting worker IP address..." -NoNewLine
$workerPublicIp = (Invoke-WebRequest -uri "http://ifconfig.me/ip" -UseBasicParsing).Content
Write-Host "Done. IP is: $workerPublicIp"

# create Connection string
switch ($authType)
{
	"sql"
    {
    	$connectionString = "Server=tcp:$sqlServerName.database.windows.net;Initial Catalog=$dbName;Persist Security Info=False;User ID=$userId;Password=$userPwd;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;"
    }
    "adPwd"
    {
    	$connectionString = "Server=tcp:$sqlServerName.database.windows.net;Initial Catalog=$dbName;Persist Security Info=False;User ID=$userId;Password=$userPwd;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=`"Active Directory Password`";"
    }
    "ad"
    {
    	$connectionString = "Server=tcp:$sqlServerName.database.windows.net;Initial Catalog=$dbName;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=`"Active Directory Integrated`";"
    }
}

# open firewall port
write-host "opening firewall on server $sqlServerName for ip: $workerPublicIp"
Invoke-Expression "az sql server firewall-rule create -g $resourceGroup -n tempOctoSqlCmd -s $sqlServerName --start-ip-address $workerPublicIp --end-ip-address $workerPublicIp"

# invoke sql cmd
try
{
	$id = New-Guid
    $resultFilePath = "$env:temp/$id.txt"
	Write-Host "running sql statement: ``$sqlCmd``"
    
    switch ($resultsOutput)
    {
        'none'
        {
        	Invoke-SqlCmd -ConnectionString $connectionString -Query $sqlCmd -QueryTimeout $connTimeout
        }

        'variable'
        {
        	Invoke-SqlCmd -ConnectionString $connectionString -Query $sqlCmd -QueryTimeout $connTimeout | ConvertTo-CSV | Out-File -FilePath "$resultFilePath"
            $outputContent = Get-Content -Path $resultFilePath | ConvertFrom-CSV
            Set-OctopusVariable -name "azDbSqlCmd.results"
        }

        'artifact'
        {
           	Invoke-SqlCmd -ConnectionString $connectionString -Query $sqlCmd -QueryTimeout $connTimeout | ConvertTo-CSV | Out-File -FilePath "$resultFilePath"
            New-OctopusArtifact -Path $resultFilePath -Name azDbSqlCmd.results.csv
        }
    }
}
catch
{
	throw
}
finally
{
  # close firewall port
  write-host "closing firewall on server $sqlServerName for ip: $workerPublicIp"
  Invoke-Expression "az sql server firewall-rule delete -g $resourceGroup -n tempOctoSqlCmd -s $sqlServerName"
}
