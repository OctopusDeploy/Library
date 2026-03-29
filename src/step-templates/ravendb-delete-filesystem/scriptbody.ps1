#--------------------------------------------------------------------
#Octopus Variables

#URL of RavenFS that is being deleted 
$ravenFileSystemURL = $OctopusParameters["ravenFileSystemURL"]

#name of the RavenFS that is being deleted
$ravenFileSystemName = $OctopusParameters["ravenFileSystemName"]

#hard delete (true or false)
$hardDelete = $OctopusParameters["hardDelete"]

#Allow File System to be deleted
$allowDelete = $OctopusParameters["allowDelete"]



Write-Output "`n-------------------------`n"
#--------------------------------------------------------------------
#checks to see if the File System can be deleted

if($allowDelete -eq $FALSE)
{
    Write-Error "$ravenFileSystemName cannot be deleted. Please try this on a database that can be delete." -ErrorId E4
    Exit 1
}


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
    Write-Output "$ravenFileSystemName exists"
    $doWork = $TRUE
}
else
{
    Write-Warning "$ravenFileSystemName doesn't exist already."
    $doWork = $FALSE
}

#--------------------------------------------------------------------
#converts hard delete option to a string

$hardDeleteString = $hardDelete.ToString().ToLower()

#--------------------------------------------------------------------
#Delete File System

if($doWork -eq $TRUE)
{

    Write-Output "Deleting File System: $ravenFileSystemName"

    $deleteURI = "$ravenFileSystemURL/admin/fs/$ravenFileSystemName" + "?hard-delete=$hardDeleteString"

    Invoke-RestMethod -Uri $deleteURI -Method Delete


    #Waits 10 seconds before it continues
    Start-Sleep -Seconds 10
    
    Write-Output "File System has successfuly been deleted"

}