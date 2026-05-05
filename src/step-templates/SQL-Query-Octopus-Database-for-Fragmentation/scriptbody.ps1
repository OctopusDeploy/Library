###PARAMETERS

[string]$sqlUsername = $OctopusParameters["IndexFragmentSQLUsername"]
[string]$sqlPassword = $OctopusParameters["IndexFragmentSQLPassword"]
[int]$threshold = $OctopusParameters["IndexFragmentFragmentation"]
[string]$SQLServer = $OctopusParameters["IndexFragmentSQLServer"]
[string]$SQLPort = $OctopusParameters["IndexFragmentSQLPort"]
[string]$databaseName = $OctopusParameters["IndexFragmentDatabaseName"]
[string]$pageCount = $OctopusParameters["IndexFragmentPageCount"]


if ([string]::IsNullOrWhiteSpace($SQLPort)){
$SQLPort = "1433"
}

#create the full sql server string
[string]$SQLServerFull = $SQLServer + "," + $SQLPort

#creating the connectionString based on choice of auth
if ([string]::IsNullOrWhiteSpace($sqlUserName)){
	Write-Highlight "Integrated Authentication being used to connect to SQL."
    $connectionString = "Server=$SQLServerFull;Database=$databaseName;integrated security=true;"
}
else {
	Write-Highlight "SQL Authentication being used to connect to SQL"
    $connectionString = "Server=$SQLServerFull;Database=$databaseName;User ID=$sqlUsername;Password=$sqlPassword;"
}

#function for running the query
function ExecuteSqlQuery ($connectionString, $SQLQuery) {
    $Datatable = New-Object System.Data.DataTable
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = $connectionString
	try{
    	$Connection.Open()
    	$Command = New-Object System.Data.SQLClient.SQLCommand
    	$Command.Connection = $Connection
    	$Command.CommandText = $SQLQuery
    	$Reader = $Command.ExecuteReader()
    	$Datatable.Load($Reader)
    }
    catch{
    	Write-Error $_.Exception.Message
    }
    finally{
    	if (($Connection.State) -ne "Closed"){
        Write-Highlight "Closing the SQL Connection."
    	$Connection.Close()   
        }
    }
    return $Datatable
}

#Create the query for fragmentation check
$query = @"
SELECT S.name as 'Schema',
T.name as 'Table',
I.name as 'Index',
DDIPS.avg_fragmentation_in_percent,
DDIPS.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS
INNER JOIN sys.tables T on T.object_id = DDIPS.object_id
INNER JOIN sys.schemas S on T.schema_id = S.schema_id
INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id
AND DDIPS.index_id = I.index_id
WHERE DDIPS.database_id = DB_ID()
and I.name is not null
AND DDIPS.avg_fragmentation_in_percent > 0
ORDER BY DDIPS.avg_fragmentation_in_percent desc
"@

#Run the query against the server and return as a dataset
$resultsDataTable = New-Object System.Data.DataTable
$resultsDataTable = ExecuteSqlQuery $connectionString $query 

#creating variables for later use
$highestFrag = 0
$array = @()

#build an array of html so the data is readable
$dataforemail = @()
$dataforemail += "<header>  <h1>SQL Fragmentation Report</h1></header><br>"
$dataforemail += '<table border="1">'
$dataforemail += "<tr> <td> Table </td><td>Index</td><td>Fragmentation %</td><td>Page Count</td></td>"
foreach ($row in $resultsDataTable){
	#checking if the current row's fragmentation % is higher than our highest if it is, set it
	if ($row.avg_fragmentation_in_percent -gt $highestFrag -and $row.page_count -gt $pageCount){
		$highestFrag = $row.avg_fragmentation_in_percent
	}
    #if both thresholds are hit, put the data in HTML format and also an array to later write to console.
	if ($row.avg_fragmentation_in_percent -gt $threshold -and $row.page_count -gt $pageCount){
        $percent = [math]::Round($row.avg_fragmentation_in_percent,2)
		$dataforemail += "<tr>" 
		$dataforemail += "<td>" + $row.Table + "</td>"
		$dataforemail += "<td>" + $row.Index + "</td>"
        $dataforemail += "<td>" + [string]$percent + "</td>"
        $dataforemail += "<td>" + $row.page_count + "</td>"
		$dataforemail += "</tr>"
        
        $arrayRow = "" | Select Table,Index,avg_fragmentation_in_percent,page_count
    	$arrayRow.Table = $Row.Table
    	$arrayRow.Index = $Row.Index
        $arrayRow.avg_fragmentation_in_percent = [string]$percent
        $arrayRow.page_count = $Row.page_count
    	$array += $arrayRow
	}
}
$dataforemail += "</table>"

#if the threshold has been reached, output data and create output variable for sending email.
if ($highestFrag -gt $threshold){

	#convert the array to a string to email
	[string]$bodyofemail = [string]$dataforemail

	#Create all of the necessary variables and output the data
		Set-OctopusVariable -name "EmailData" -value "$dataforemail"
        Set-OctopusVariable -name "Alert" -value "True"
        $output = $array | Out-String
        Write-Highlight 'Here are the results for your database fragmentation. The following tables had above the provided fragmentation % and minimum page count. If you would like to get an email alert with the data, please refer to the description of the step template for instructions on setting that up.'
        Write-Highlight $output
}
else{

	Write-Highlight "No alert is required."
    Set-OctopusVariable -name "Alert" -value "False"


}
