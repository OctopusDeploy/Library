#--------------------------------------------------------------------
#File System Octopus Variables

#URL of RavenFS that is being deleted 
$ravenFileSystemURL = $OctopusParameters["ravenFileSystemURL"]

#name of the RavenFS that is being deleted
$ravenFileSystemName = $OctopusParameters["ravenFileSystemName"]

#--------------------------------------------------------------------
#Settings Octopus Variables

#Name of Active Bundles (Replication; Versioning; etc) (Default is none)
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

#checks to see if the entered file system exists, return a Boolean value depending on the outcome
function doesRavenFSExist([string] $FSChecking, [string]$URL)
{
    #retrieves the list of File Systems at the specified URL
    $fs_list = Invoke-RestMethod -Uri "$URL/fs" -Method Get
    #checks if the File System is at the specified URL
    if ($fs_list -contains $FSChecking.ToString()) 
    {
        return $TRUE
    }
    else 
    {
        return $FALSE
    }

    
}#ends does File System exist function


Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#check to see if File System exists

Write-Output "Checking if $ravenFileSystemName exists"

$fs_exists = doesRavenFSExist -FSChecking $ravenFileSystemName -URL $ravenFileSystemURL

if($fs_exists -eq $TRUE)
{
    Write-Error "$ravenFileSystemName already exists" -ErrorId E4
    Exit 1
}
else
{
    Write-Output "$ravenFileSystemName doesn't exist. Creating $ravenFileSystemName now"
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

$ravenDataDir = $ravenDataDir.Replace("DB", "FS")

$voronTempPath = $voronTempPath.Replace("DB", "FS")

$esentLogsPath = $esentLogsPath.Replace("DB", "FS")

$indexStoragePath = $indexStoragePath.Replace("DB", "FS")

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#file system settings


$fs_settings = @"
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
#Create File System

Write-Output "Creating File System: $ravenFileSystemName"

$createURI = "$ravenFileSystemURL/admin/fs/$ravenFileSystemName"

Invoke-RestMethod -Uri $createURI -Body $fs_settings -Method Put

Write-Output "$ravenFileSystemName created."
