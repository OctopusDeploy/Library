
# Variables

#Location of the Raven Smuggler exe
$ravenSmugglerPath = $OctopusParameters["ravenSmugglerPath"]


#--------------------------------------------------------------------
# Source File System Variables

#URL of RavenFS that is being backed up 
$sourceFileSystemURL = $OctopusParameters["sourceFileSystemURL"]

#name of the RavenFS that is being backed up
$sourceFileSystemName = $OctopusParameters["sourceFileSystemName"]

#API Key for the Source File System
$sourceFileSystemApiKey = $OctopusParameters["sourceFileSystemApiKey"]




#--------------------------------------------------------------------
#Destination File System Variables

#URL of destination RavenFS 
$destinationFileSystemURL = $OctopusParameters["destinationFileSystemURL"]

#Name of the destination RavenFS
$destinationFileSystemName = $OctopusParameters["destinationFileSystemName"]

#API Key for the Destination File System
$destinationFileSystemAPIKey = $OctopusParameters["destinationFileSystemAPIKey"]


#--------------------------------------------------------------------
# Other Variables retrieved from Octopus

#Get timeout variable
$timeout = $OctopusParameters["timeout"]



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

#Check path to smuggler
Write-Output "Checking if Smuggler path is correct`n"

$smuggler_Exists = Test-Path -Path $ravenSmugglerPath



#if the path is correct, the script continues, throws an error if the path is wrong
If($smuggler_Exists -eq $TRUE)
{
    Write-Output "Smuggler exists"

}#ends if smuggler exists 
else
{
    Write-Error "Smuggler cannot be found `nCheck the directory: $ravenSmugglerPath" -ErrorId E4
    Exit 1
}#ends else, smuggler can't be found

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#Checking the version of smuggler

$SmugglerVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ravenSmugglerPath).FileVersion

if($SmugglerVersion -cgt "3")
{
    Write-Host "Smuggler Version: $SmugglerVersion"
}
else
{
    Write-Error "The version of Smuggler that is installed can NOT complete this step. `nPlease update Smuggler before continuing" -ErrorId E4
    Exit 1
}
Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------

#Check if Source File System and destination File System exists
Write-Output "Checking if both $sourceFileSystemName and $destinationFileSystemName exist`n"

$sourceFS_exists = doesRavenFSExist -FSChecking $sourceFileSystemName -URL $sourceFileSystemURL 

$DestinationFS_Exist = doesRavenFSExist -FSChecking $destinationFileSystemName -URL $destinationFileSystemURL


#if both File System exist a backup occurs
if(($sourceFS_exists -eq $TRUE) -and ($DestinationFS_Exist -eq $TRUE))
{

    Write-Output "Both $sourceFileSystemName and $destinationFileSystemName exist`n"

}#ends if 
#if the source File System doesn’t exist an error is throw
elseIf(($sourceFS_exists -eq $FALSE) -and ($DestinationFS_Exist -eq $TRUE))
{

    Write-Error "$sourceFileSystemName does not exist. `nMake sure the File System exists before continuing" -ErrorId E4
    Exit 1

}
#if the destination File System doesn’t exist an error is throw
elseIf(($DestinationFS_Exist -eq $FALSE) -and ($sourceFS_exists -eq $TRUE))
{

    Write-Error "$destinationFileSystemName does not exist. `nMake sure the File System exists before continuing" -ErrorId E4
    Exit 1

}#ends destination FS not exists
else
{
 
    Write-Error "Neither $sourceFileSystemName or $destinationFileSystemName exists. `nMake sure both File Systems exists" -ErrorId E4
    Exit 1

}#ends else

Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#start Backup

try
{
    Write-Output "Attempting Backup up now"
    Write-Output "`n-------------------------`n"
    & $ravenSmugglerPath between $sourceFileSystemURL $destinationFileSystemURL --filesystem=$sourceFileSystemName --filesystem2=$destinationFileSystemName --api-key=$sourceFileSystemApiKey --api-key2=$destinationFileSystemAPIKey --timeout=$timeout
    Write-Output "`n-------------------------`n"
    Write-Output "Backup successful"


}#ends try
catch
{
    Write-Error "An error occurred during backup, please try again" -ErrorId E4
    Exit 1
}#ends catch
