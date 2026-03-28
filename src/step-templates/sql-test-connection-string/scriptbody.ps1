#Create SQL Connection
$con = new-object "System.data.sqlclient.SQLconnection"
Write-Host "Opening SQL connection to $ConnectionString"

$con.ConnectionString =("$ConnectionString")
try {
    $con.Open()
    Write-Host "Successfully opened connection to the database"
}
catch {
    $error[0]
    exit 1
}
finally{
    Write-Host "Closing SQL connection"
    $con.Close()
    $con.Dispose()
    Write-Host "Connection closed."
}