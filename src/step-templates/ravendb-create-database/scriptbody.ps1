#--------------------------------------------------------------------
#Octopus Variables

#URL where the database will be create
$ravenDatabaseURL = $OctopusParameters["ravenDatabaseURL"]

#Name of the new database
$ravenDatabaseName = $OctopusParameters["ravenDatabaseName"]

#Name of Active Bundles (Replication; Versioning; etc) (Default is null)
$ravenActiveBundles = $OctopusParameters["ravenActiveBundles"]

#storage Type Name (esent or voron)
$ravenStorageTypeName = $OctopusParameters["ravenStorageTypeName"]

#directory the database will be located on the server
$ravenDataDir = $OctopusParameters["ravenDataDir"]

#allow incremental back ups: boolean
$allowIncrementalBackups = $OctopusParameters["allowIncrementalBackups"]

#temporary files will be created at this location
$voronTempPath = $OctopusParameters["voronTempPath"]

#The path for the esent logs
$esentLogsPath = $OctopusParameters["esentLogsPath"]

#The path for the indexes on a disk
$indexStoragePath = $OctopusParameters["indexStoragePath"]


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
    Write-Error "$ravenDatabaseName already exists" -ErrorId E4
    Exit 1
}



Write-Output "`n-------------------------`n"
#--------------------------------------------------------------------
#check setting variables 

if($ravenActiveBundles -eq $null)
{
   $ravenActiveBundles = "" 
}

if($ravenDataDir -eq "")
{
    Write-Warning "A directory for the database has NOT been entered. The default directory ~\Databases\System is being used."
    $ravenDataDir  = "~\Databases\System"
}

if($esentLogsPath -eq "")
{
    Write-Warning "The path for the esent logs has NOT been entered. The default path of ~/Data/Logs will be used"
    $esentLogsPath =  "~/Data/Logs"
}

if($indexStoragePath -eq "")
{
    Write-Warning "The path for the indexes has NOT been entered. The default path of ~/Data/Indexes will be used"
    $indexStoragePath = "~/Data/Indexes"
}


$ravenDataDir = $ravenDataDir.Replace("\", "\\")

$voronTempPath = $voronTempPath.Replace("\", "\\")

$esentLogsPath = $esentLogsPath.Replace("\", "\\")

$indexStoragePath = $indexStoragePath.Replace("\", "\\")

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#database Settings 

$db_settings = @"
{
   "Settings":
   {
   "Raven/ActiveBundles": "$ravenActiveBundles",
    "Raven/StorageTypeName": "$ravenStorageTypeName",
    "Raven/DataDir": "$ravenDataDir",
    "Raven/Voron/AllowIncrementalBackups": "$allowIncrementalBackups",
    "Raven/Voron/TempPath": "$voronTempPath",
    "Raven/Esent/LogsPath": "$esentLogsPath",
    "Raven/IndexStoragePath": "$indexStoragePath"
   }
}
"@

#--------------------------------------------------------------------
#create Database

Write-Output "Create database: $ravenDatabaseName"

$createURI = "$ravenDatabaseURL/admin/databases/$ravenDatabaseName"

Invoke-RestMethod -Uri $createURI -Body $db_settings -Method Put
