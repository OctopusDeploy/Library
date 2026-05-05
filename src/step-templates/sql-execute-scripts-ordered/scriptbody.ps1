
$paramContinueOnError = $OctopusParameters['ContinueOnError']
if($paramContinueOnError -eq $null) { $paramContinueOnError = 'False' }

$paramVersionRegEx = $OctopusParameters['VersionRegEx']
if($paramVersionRegEx -eq $null) { $paramVersionRegEx = 'Release(\d+)_(\d+)\.' }

$paramPathToScripts = $OctopusParameters['PathToScripts'] 
if($paramPathToScripts -eq $null) { throw "*** Path to scrips must be defined." }

$paramCommandTimeout = $OctopusParameters['CommandTimeout'] 
if($paramCommandTimeout -eq $null) { $paramCommandTimeout = '0' }

$paramConnectionString = $OctopusParameters['ConnectionString']
if($paramConnectionString -eq $null) { throw "*** Connection string must be defined." }

$continueOnError = $paramContinueOnError.ToLower() -eq 'true'

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $paramConnectionString

Register-ObjectEvent -inputobject $connection -eventname InfoMessage -action {
    write-host $event.SourceEventArgs
} | Out-Null

function Execute-SqlQuery($fileName) 
{
    Write-Host "Executing scripts in file '$fileName'"

    $content = gc $fileName -raw
    $queries = [System.Text.RegularExpressions.Regex]::Split($content, '\r\n\s*GO\s*\r\n', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | ? { $_ -ne '' }

    foreach($q in $queries)
    {
        if ((-not [String]::IsNullOrWhiteSpace($q)) -and ($q.Trim().ToLowerInvariant() -ne "go")) 
        {   
            $command = $connection.CreateCommand()
            $command.CommandText = $q
            $command.CommandTimeout = $paramCommandTimeout
            $command.ExecuteNonQuery() | Out-Null
        }
    }
}

try 
{
    Write-Host "Executing scripts in folder '$paramPathToScripts'"

    Write-Host "Sorting script files based on regular expression '$paramVersionRegEx'"
    
    Write-Host "Opening SQL server connection..."
    $connection.Open()

    Get-ChildItem $paramPathToScripts *.sql |
        % { 
            $matches = [System.Text.RegularExpressions.Regex]::Match($_.Name, $paramVersionRegEx, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase )
            new-object psobject -Property @{ "File"=$_; "Level1"=$matches.Groups[1]; "Level2"=$matches.Groups[2] }
          } | 
          sort Level1, Level2 |
          % {
              Execute-SqlQuery -fileName $_.File.FullName
            }
}
catch 
{
	if ($continueOnError) 
	{
		Write-Host $_.Exception.Message
	}
	else 
	{
		throw
	}
}
finally 
{
    Write-Host "Closing connection."
    $connection.Dispose()
}
