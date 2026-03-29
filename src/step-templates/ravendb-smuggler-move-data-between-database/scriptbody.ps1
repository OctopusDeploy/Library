
# Variables

#Location of the Raven Smuggler exe
$ravenSmugglerPath = $OctopusParameters["ravenSmugglerPath"]


#--------------------------------------------------------------------
# Source Database Variables

#URL of RavenDB that is being backed up 
$sourceDatabaseURL = $OctopusParameters["sourceDatabaseURL"]

#name of the RavenDB that is being backed up
$sourceDatabaseName = $OctopusParameters["sourceDatabaseName"]

#API Key for the Source Database
$sourceDatabaseApiKey = $OctopusParameters["sourceDatabaseApiKey"]


#--------------------------------------------------------------------
#Destination Database Variables

#URL of destination RavenDB 
$destinationDatabaseURL = $OctopusParameters["destinationDatabaseURL"]

#Name of the destination RavenDB
$destinationDatabaseName = $OctopusParameters["destinationDatabaseName"]

#API Key for the Destination Database
$destinationDatabaseAPIKey = $OctopusParameters["destinationDatabaseAPIKey"]



#------------------------------------------------------------------------------
# Other Variables retrieved from Octopus

#Limit the back up to different types in the database
#Get document option (true/false)
$operateOnDocuments = $OctopusParameters["operateOnDocuments"]

#Get attachments option (true/false)
$operateOnAttachments = $OctopusParameters["operateOnAttachments"]

#Get indexes option (true/false)
$operateOnIndexes = $OctopusParameters["operateOnIndexes"]

#Get transformers option (true/false)
$operateOnTransformers = $OctopusParameters["operateOnTransformers"]

#Get timeout option 
$timeout = $OctopusParameters["timeout"]

#Get wait for indexing option (true/false)
$waitForIndexing = $OctopusParameters["waitForIndexing"]


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
#Checking the versions of Raven Server of both databases to see if they are compatible 

Write-Output "Checking that both $sourceDatabaseName and $destinationDatabaseName are running the same version of RavenDB"

#Getting Source Database's build version
$sourceVersionURL = "$sourceDatabaseURL/databases/$sourceDatabaseName/build/version"

$sourceDatabaseVersion = Invoke-RestMethod -Uri $sourceVersionURL -Method Get

#Getting destination Database's build version
$destinationVersionURL = "$destinationDatabaseURL/databases/$destinationDatabaseName/build/version"

$destinationDatabaseVersion = Invoke-RestMethod -Uri $destinationVersionURL -Method Get

#Checks to see if they are the same version and build number
if(($sourceDatabaseVersion.ProductVersion -eq $destinationDatabaseVersion.ProductVersion) -and ($sourceDatabaseVersion.BuildVersion -eq $destinationDatabaseVersion.BuildVersion))
{
    
    Write-Output "Source Database Product Version:" $sourceDatabaseVersion.ProductVersion 
    Write-Output "Source Database Build Version:" $sourceDatabaseVersion.BuildVersion
    Write-Output "Destination Database Version:" $destinationDatabaseVersion.ProductVersion 
    Write-Output "Destination Database Build Version:" $destinationDatabaseVersion.BuildVersion
    Write-Output "Source and destination Databases are running the same version of Raven Server"
    
}
else 
{
    Write-Warning "Source Database Version: $sourceDatabaseVersion"
    Write-Warning "Destination Database Version: $destinationDatabaseVersion"
    Write-Warning "The databases are running different versions of Raven Server"
}

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------

#Check path to smuggler
Write-Output "Checking if Smuggler path is correct`n"

$smugglerPath = "$ravenSmugglerPath"

$smuggler_Exists = Test-Path -Path $smugglerPath



#if the path is correct, the script continues, throws an error if the path is wrong
If($smuggler_Exists -eq $TRUE)
{
    Write-Output "Smuggler exists"

}#ends if smuggler exists 
else
{
    Write-Error "Smuggler can not be found `nCheck the directory: $ravenSmugglerPath" -ErrorId E4
    Exit 1
}#ends else, smuggler can't be found

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#Checking the version of smuggler

$SmugglerVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ravenSmugglerPath).FileVersion

if($SmugglerVersion -cgt "3")
{
    Write-Output "Smuggler Version: $SmugglerVersion"
}
else
{
    Write-Error "The version of Smuggler that is installed can NOT complete this step `nPlease update Smuggler before continuing" -ErrorId E4
    Exit 1
}
Write-Output "`n-------------------------`n"





#--------------------------------------------------------------------


#Checks if both Source database and destination database exist
Write-Output "Checking if both $sourceDatabaseName and $destinationDatabaseName exist`n"

$sourceDatabase_exists = doesRavenDBExist -databaseChecking $sourceDatabaseName -URL $sourceDatabaseURL 

$destinationDatabase_exists = doesRavenDBExist -databaseChecking $destinationDatabaseName -URL $destinationDatabaseURL


#if both database exist a backup occurs
if(($sourceDatabase_exists -eq $TRUE) -and ($destinationDatabase_exists -eq $TRUE))
{

    Write-Output "Both $sourceDatabaseName and $destinationDatabaseName exist`n"

}#ends if 
#if the source database doesn’t exist an error is throw
elseIf(($sourceDatabase_exists -eq $FALSE) -and ($destinationDatabase_exists -eq $TRUE))
{

    Write-Error "$sourceDatabaseName does not exist. `nMake sure the database exists before continuing" -ErrorId E4
    Exit 1

}
#if the destination database doesn’t exist an error is throw
elseIf(($destinationDatabase_exists -eq $FALSE) -and ($sourceDatabase_exists -eq $TRUE))
{

    Write-Error "$destinationDatabaseName does not exist. `nMake sure the database exists before continuing" -ErrorId E4
    Exit 1

}#ends destination db not exists
else
{

    Write-Error "Neither $sourceDatabaseName or $destinationDatabaseName exists. `nMake sure both databases exists" -ErrorId E4
    Exit 1

}#ends else

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#changing the types to export/import

$operateTypes = @()


if($operateOnDocuments -eq $TRUE)
{
    $operateTypes += "Documents"
}
if($operateOnIndexes -eq $TRUE)
{
    $operateTypes += "Indexes"
}
if($operateOnAttachments -eq $TRUE)
{
    $operateTypes += "Attachments"
}
if($operateOnTransformers -eq $TRUE)
{
    $operateTypes += "Transformers"
}

$Types = $operateTypes -join ","

if($Types -ne "")
{
    Write-Output "This back up is only operating on $Types"

    Write-Output "`n-------------------------`n"
}


#--------------------------------------------------------------------
#check if wait for indexing is selected
$Indexing = ""

if($waitForIndexing -eq $TRUE)
{
    $Indexing = "--wait-for-indexing"
}

#--------------------------------------------------------------------
#backing up source database into the destination database

try
{
    Write-Output "Attempting Backup up now"
    Write-Output "`n-------------------------`n"
    & $ravenSmugglerPath between $sourceDatabaseURL $destinationDatabaseURL --database=$sourceDatabaseName --database2=$destinationDatabaseName --api-key=$sourceDatabaseApiKey --api-key2=$destinationDatabaseAPIKey --timeout=$Timeout $Indexing 
    Write-Output "`n-------------------------`n"
    Write-Output "Backup successful" 
}#ends try
catch
{
    Write-Error "An error occurred during backup, please try again" -ErrorId E4
    Exit 1
}#ends catch 
