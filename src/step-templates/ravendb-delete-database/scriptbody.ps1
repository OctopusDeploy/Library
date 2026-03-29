#--------------------------------------------------------------------
#Octopus Variables

#URL where the database can be found
$ravenDatabaseURL = $OctopusParameters["ravenDatabaseURL"]

#Name of the Database
$ravenDatabaseName = $OctopusParameters["ravenDatabaseName"]

#hard delete (true or false)
$hardDelete = $OctopusParameters["hardDelete"]

#Allow Database to be deleted
$allowDelete = $OctopusParameters["allowDelete"]



Write-Output "`n-------------------------`n"
#--------------------------------------------------------------------
#checks to see if the database can be deleted

if($allowDelete -eq $FALSE)
{
    Write-Error "$ravenDatabaseName cannot be deleted. Please try this on a database that can be delete." -ErrorId E4
    Exit 1
}


#--------------------------------------------------------------------

#checks to see if the entered database exists, return a boolean value depending on the outcome
function doesRavenDBExist([string] $databaseChecking, [string]$URL)
{
    #retrieves the list of databases at the specified URL
    $database_list = Invoke-RestMethod -Uri "$URL/databases" -Method Get
    #checks if the database is at the specified URL
    if ($database_list -contains $databaseChecking.ToString()) 
    {
        return $TRUE
    }
    else 
    {
        return $FALSE
    }

    
}#ends does ravenDB exist function

Write-Output "`n-------------------------`n"


#--------------------------------------------------------------------

#check to see if database exists
Write-Output "Checking to see if $ravenDatabaseName exists"

$database_exists = doesRavenDBExist -databaseChecking $ravenDatabaseName -URL $ravenDatabaseURL

if($database_exists -eq $TRUE)
{
    Write-Output "$ravenDatabaseName exists"
    $doWork = $TRUE
}
else
{
    Write-Warning "$ravenDatabaseName does not exist already." 
    $doWork = $FALSE
}


Write-Output "`n-------------------------`n"


#--------------------------------------------------------------------
#hard delete option

$hardDeleteString = $hardDelete.ToString().ToLower()



#--------------------------------------------------------------------
#Delete database

if($doWork -eq $TRUE)
{

    Write-Output "Deleting Database: $ravenDatabaseName"

    $deleteURI = "$ravenDatabaseURL/admin/databases/$ravenDatabaseName" + "?hard-delete=$hardDeleteString"

    Invoke-RestMethod -Uri $deleteURI -Method Delete

    #Waits 10 seconds before it continues
    Start-Sleep -Seconds 10
    
    Write-Output "Database has successfuly been deleted"

}