#--------------------------------------------------------------------
#Log In Variables

$dynLogInURI = "https://api.dynect.net/REST/Session/"

$dynCustomerName = $OctopusParameters["dynCustomerName"] 

$dynUserName = $OctopusParameters["dynUserName"] 

$dynPassword = $OctopusParameters["dynPassword"] 

#--------------------------------------------------------------------
#Get A Record Variables

$dynARecordURI = "https://api.dynect.net/REST/ARecord"

$dynZone = $OctopusParameters["dynZone"]

$dynFQDN = $OctopusParameters["dynFQDN"] 

#--------------------------------------------------------------------
#A Record information to check

$createNewARecord = $FALSE

$UpdateARecord = $FALSE

$dynCorrectTTL = $OctopusParameters["dynCorrectTTL"]

$dynCorrectIPAddress = $OctopusParameters["dynCorrectIPAddress"] 


#--------------------------------------------------------------------
#Publish Zone Variables

$dynPublishURI = "https://api.dynect.net/REST/Zone"

$publishZone = $FALSE




Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#Log In and Retrieve Token for this session

Write-Output "Logging into Dyn and retrieving session Authentication Token."

$dynCredentials = @{}

$dynCredentials.Add("customer_name", $dynCustomerName)
$dynCredentials.Add("user_name", $dynUserName)
$dynCredentials.Add("password", $dynPassword)

$dynCredentialsJSON = ConvertTo-Json -InputObject $dynCredentials

$dynLoginResults = Invoke-RestMethod -Uri $dynLogInURI -Body $dynCredentialsJSON -ContentType 'application/json' -Method Post

if($dynLoginResults.status -ne "success")
{
    Write-Error "Invalid Log In Details. Please try again." -ErrorId E4
}
else
{
    Write-Output "`nLog in was successful."
}



$dynSessionToken = @{}

$dynSessionToken.Add("Auth-Token", $dynLoginResults.data.token)


Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#Get A Record 

Write-Output "Retrieving specified A record information.`n"

#get and search all records to get the correct record ID (not a unique id) for existing A Records
#this is done to check if a A Record does not exist already. This is the only way to do it without getting an error.
$dynAllRecordsURI = "https://api.dynect.net/REST/AllRecord/$dynZone"

 
$dynAllRecordResults = Invoke-RestMethod -Uri $dynAllRecordsURI -Headers $dynSessionToken -ContentType 'application/json' -Method Get 

for($i = 0; $i -lt $dynAllRecordResults.data.Length; $i++)
{
    
    $a = $dynAllRecordResults.data.Get($i)

    $result = $a.contains($dynFQDN)

    if($result -eq $TRUE)
    {
        $dynARecordString = $dynAllRecordResults.data.Get($i)

        $dynARecordExists = $TRUE

        $i = $dynAllRecordResults.data.Length
    }
    else
    {
        $dynARecordExists = $FALSE
    }
}



#checks to see if there is more than one A record with the same name.
if($dynARecordExists -eq $TRUE)
{
    $dynARecordURI = "$dynARecordURI/$dynZone/$dynFQDN" 
 
    $dynARecordResults = Invoke-RestMethod -Uri $dynARecordURI -Headers $dynSessionToken -ContentType 'application/json' -Method Get 

    if($dynARecordResults.data.Length -gt 1)
    {
        Write-Error "`nThere is more than one A record with the Fully Qualified Domain Name (FQDN) of $dynFQDN. `nThis script does not handle more than one A record witht the same FQDN" -ErrorId E1
    }

    if($dynARecordResults.status -ne "success")
    {
        Write-Error "Error occurred while trying to retrieve the A Record. Please check the host name and the Fully Qualified Domain Name are correct." -ErrorId E1
    }
}



#Checks if the an A record was returned or needs to be created
if(($dynARecordResults.data.Length -eq 0) -or ($dynARecordExists -eq $FALSE))
{
    $createNewARecord = $TRUE

    Write-Warning "$dynFQDN does not exists. Creating $dynFQDN now."
}
else
{
    #get information for the specified record
    $dynARecordString = $dynARecordResults.data

    $dynARecordURI = "https://api.dynect.net$dynARecordString/"

    $dynARecord = Invoke-RestMethod -Uri $dynARecordURI -Headers $dynSessionToken -ContentType 'application/json' -Method Get 

    $dynARecord = $dynARecord.data

    Write-Output "`n$dynFQDN has successfully been retrieved."
    
    Write-Output "`n-------------------------`n"

}

#--------------------------------------------------------------------
#create new A record

if($createNewARecord -eq $TRUE)
{
    $dynCreateURI = "https://api.dynect.net/REST/ARecord/$dynZone/$dynFQDN"   

    $rData = @{}

    $rData.Add("address", $dynCorrectIPAddress)

    $dynCreateARecord = @{}

    $dynCreateARecord.Add("ttl", $dynCorrectTTL)
    $dynCreateARecord.Add("rdata", $rData)

    $dynCreateARecordJSON = ConvertTo-Json -InputObject $dynCreateARecord

    $dynCreateResult = Invoke-RestMethod -Uri $dynCreateURI -ContentType 'application/json' -Headers $dynSessionToken -Body $dynCreateARecordJSON  -Method Post

    if($dynCreateResult.status -ne "success")
    {
        Write-Error "An error occurred while creating the new A Record. Please check the details that have been entered are correct and try again." -ErrorId E4

    }
    else
    {
        Write-Output "$dynFQDN has successfully been added to the $dynZone zone in Dyn."

        $publishZone = $TRUE
    }

    Write-Output "`n-------------------------`n"


}



#--------------------------------------------------------------------
#checking specified A Record to see if it is correct if it exists
if($createNewARecord -eq $FALSE)
{
    Write-Output "Checking to see if $dynFQDN is current and contains the correct information."

    if($dynARecord.rdata.address -ne $dynCorrectIPAddress)
    {
        $UpdateARecord = $TRUE

        Write-Warning "`n$dynFQDN is out of date. Updating now"

    }

    if($UpdateARecord -eq $FALSE)
    {
        Write-Output "`n$dynFQDN is up-to-date"
    }

    Write-Output "`n-------------------------`n"
}
#--------------------------------------------------------------------
#Update A record

if($UpdateARecord -eq $TRUE)
{
    Write-Output "Updating $dynFQDN so that is matches the current information saved in the system."

    $dynUpdateURI = $dynARecordURI

    $rData = @{}

    $rData.Add("address", $dynCorrectIPAddress)

    $dynUpdatedARecord = @{}

    
    $dynUpdatedARecord.Add("ttl", $dynCorrectTTL)
    $dynUpdatedARecord.Add("rdata", $rData)

    $dynUpdatedARecord = ConvertTo-Json -InputObject $dynUpdatedARecord

    $dynUpdateResult = Invoke-RestMethod -Uri $dynUpdateURI -ContentType 'application/json' -Headers $dynSessionToken -Body $dynUpdatedARecord -Method Put
    
    if($dynUpdateResult.status -ne "success")
    {
        Write-Error "An error occured while trying to update the $dynFQDN record"
    }
    else
    {
        Write-Output "`nUpdate was successful. Just needs to be published to make it offical."
        
        $publishZone = $TRUE

    }


    Write-Output "`n-------------------------`n"

}

#--------------------------------------------------------------------
#publish update or creation of A Record

if($publishZone -eq $TRUE)
{

    Write-Output "Publishing changes made to $dynZone"

    $publish = @{}
    $publish.Add("publish", 'true')

    $publish = ConvertTo-Json -InputObject $publish

    $dynPublishURI = "$dynPublishURI/$dynZone/"

    $dynPublishResults = Invoke-RestMethod -Uri $dynPublishURI -ContentType 'application/json' -Headers $dynSessionToken -Body $publish -Method Put

    if($dynPublishResults.status -ne "success")
    {
        Write-Error "An error occurred during the publication of the $dynZone zone." -ErrorId E4
    }
    else
    {
        Write-Output "`n$dynZone has successfully been published."
    }

        Write-Output "`n-------------------------`n"

}




#--------------------------------------------------------------------
#Log Out of session

Write-Output "Logging out and deleting this session's authentication token"

$dynLogOutResults = Invoke-RestMethod -Uri $dynLogInURI -ContentType 'application/json' -Headers $dynSessionToken -Method Delete

While(($dynLogOutResults.status -ne "success") -and ($tries -lt 10))
{
    Write-Output "`nWaiting to log out of Dyn"
    $tries++
    Start-Sleep -Seconds 1
}

if($dynLogOutResults.status -eq "success")
{
    $dynSessionToken.Clear()
    Write-Output $dynSessionToken
    Write-Output "`nThis session has been ended successfully and the authentication token has been deleted."
    
}
else
{
    Write-Error "`nAn error occurred while logging out." -ErrorId E4
}

