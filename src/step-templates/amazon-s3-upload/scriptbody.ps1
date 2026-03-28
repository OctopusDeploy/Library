
$recurse = [boolean]::Parse($Recursive)

$params = @{}

#Sets the Permissions to public if the selection is true
if ($MakePublic -eq $True) {
    $params.add("CannedACLName", "public-read")
}

#Initialises the S3 Credentials based on the Access Key and Secret Key provided, so that we can invoke the APIs further down
Set-AWSCredentials -AccessKey $S3AccessKey -SecretKey $S3SecretKey -StoreAs S3Creds

#Initialises the Default AWS Region based on the region provided
Set-DefaultAWSRegion -Region $S3Region

#Gets all relevant files and uploads them
function Upload($item) 
{
    #Gets all files and child folders within the given directory
    foreach ($i in Get-ChildItem $item) {

        #Checks if the item is a folder
        if($i -is [System.IO.DirectoryInfo]) {

            #Inserts all files within a folder to AWS           
            Write-S3Object -ProfileName S3Creds -BucketName $S3Bucket -KeyPrefix $S3Prefix$($i.Name) -Folder $i.FullName -Recurse:$recurse @params

        } else {

            #Inserts file to AWS
            Write-S3Object -ProfileName S3Creds -BucketName $S3Bucket -Key $S3Prefix$($i.Name) -File $i.FullName @params

        }
    }
}

Upload($SourceFolderLocation)
