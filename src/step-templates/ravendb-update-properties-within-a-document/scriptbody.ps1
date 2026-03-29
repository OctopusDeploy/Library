
#Variables

#--------------------------------------------------------------------
#RavenDB database variables

#URL address of RavenDB
$ravenDatabaseURL = $OctopusParameters["ravenDatabaseURL"]

#Name of the database
$ravenDatabaseName = $OctopusParameters["ravenDatabaseName"]

#--------------------------------------------------------------------
#RavenDB Query variables

#Raven Query
#$ravenQuery = $OctopusParameters["ravenQuery"]

#Name of the settings document
$ravenDocumentName = $OctopusParameters["ravenDocumentName"]

#--------------------------------------------------------------------
#Setting Variables

#list of settings variables that are to be changed
$includeSettingList = $OctopusParameters["includeSettingList"]

#list of settings variables that are NOT to be changed
$excludeSettingList = $OctopusParameters["excludeSettingList"]

#--------------------------------------------------------------------
#Metadata variables

#list of metadata variables that are to be changed
$includeMetadataList = $OctopusParameters["includeMetadataList"]

#list of metadata variables that are NOT to be changed
$excludeMetadataList = $OctopusParameters["excludeMetadataList"]


#--------------------------------------------------------------------
#other variables

$octopusVariableList = $OctopusParameters.GetEnumerator()



Write-Output "`n-------------------------`n"
#--------------------------------------------------------------------
#checks to see if the entered database exists, return a Boolean value depending on the outcome
function doesRavenDBExist([string] $databaseChecking, [string]$URL)
{
    #retrieves the list of databases at the specified URL
    $database_list = Invoke-RestMethod -Uri "$ravenDatabaseURL/databases" -Method Get
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
#check to see if the database exists
       

Write-Output "Checking if $ravenDatabaseName exists"

$database_exists = doesRavenDBExist -databaseChecking $ravenDatabaseName -URL $ravenDatabaseURL


#only proceeds if database exists
if ($database_exists -eq $TRUE)
{
    Write-Output "$ravenDatabaseName exists"
            
}#ends database exists if statement 
else 
{
    Write-Error "$ravenDatabaseName doesn't exists. `nMake sure the database exists before continuing" -ErrorId E4
    Exit 1
}


Write-Output "`n-------------------------`n"   
         
#--------------------------------------------------------------------
#Get current setings and change them accordingly

$allSettingsJSON = $null

Write-Output "Getting Document: $ravenDatabaseName"

$settingsURI = "$ravenDatabaseURL/databases/$ravenDatabaseName/docs/$ravenDocumentName"

    

try {
    #Gets settings from the specific Uri
    $allSettings = Invoke-RestMethod -Uri $settingsURI -Method Get

} catch {
    if ($_.Exception.Response.StatusCode.Value__ -ne 404) {
  
    $_.Exception
    }
}

#check to make sure the query return some results
if($allSettings -eq $null)
{
    Write-Error "An error occurred while querying the database. `nThe query did not return any values. `nPlease enter a new query" -ErrorId E4
    Exit 1
}

$includeList = @()

($includeSettingList.Split(", ") | ForEach {
    $includeList += $_.ToString()
})

     
Write-Output "Updating the Settings document"
try
{
    

    #changes the values of the included settings within the original settings document to values from Octopus Variables
    for($i = 0; $i -lt $includeList.length; $i++)
    {
        
        
        #checks if the any of the include setting list is in the exclude setting list
        if($excludeSettingList -notcontains $includeList[$i])
        {
            
            
            $octopusVariableList = $OctopusParameters.GetEnumerator()
            
            #loops through the variable list to find the corresponding value to the settings variable
            foreach($varKey in $octopusVariableList)
            {
                
                
                $newSettingVar = $includeList[$i].ToString()
                
                $newSettingVar = "Property_$newSettingVar"
                
                #sets the setting variable to the correct variable in octopus
                if($varKey.Key -eq $newSettingVar)
                {
                    
                    

                    $allSettings.($includeList[$i]) = $varKey.Value 

                }#ends if

            }#ends for each



        }#ends check if settings in excluded list


    }#ends for
}#ends try
catch
{
    Write-Error "An error occurred while trying to find the Setting Variables." -ErrorId E4
    Exit 1
}


Write-Output "Update complete"

Write-Output "`n-----------------------------"

#--------------------------------------------------------------------
#set update metadata information

Write-Output "Updating the Metadata of the document"

$metadata = @{}

$metadataList = @()

($includeMetadataList.Split(", ") | Foreach {
    $metadataList += $_.ToString()
})


try
{
    for($i = 0; $i -lt $metadataList.length; $i++)
    {
    
        if($excludeMetadataList -notcontains $metadataList[$i])
        {
        
            $octopusVariableList = $OctopusParameters.GetEnumerator()
        
            foreach($varKey in $octopusVariableList)
            {
                
                $newMetadataVar = $metadataList[$i]
                
                $newMetadataVar = "Property_$newMetadataVar"

                if($varKey.Key -eq $newMetadataVar)
                {
                    
                    $temp = $metadataList[$i].ToString()
                    
                    $metadata.Add("$temp", $varKey.Value)
                    
                    
                }
            
            }#ends foreach

        }#ends if

    }#Ends for 
}#ends try
catch
{
    Write-Error "An error occurred while trying to find the Metadata Variables." -ErrorId E4
    Exit 1
}


Write-Output "Metadata update complete"



#--------------------------------------------------------------------
#converting settings to a JSON document

Write-Output "Converting settings to a JSON document"

#Converts allSettings to JSON so it can be added to RavenDB
if ($allSettingsJSON -eq $null) 
{
    $allSettingsJSON = ConvertTo-Json -InputObject $allSettings
}



Write-Output "`n-------------------------`n"

#--------------------------------------------------------------------
#inserting settings document

Write-Output "Restoring Document: $ravenDatabaseName . Inserting the new settings document to the database"

#URL to put the JSON document
$putSettingsURI = "$ravenDatabaseURL/databases/$ravenDatabaseName/docs/$ravenDocumentName"

#Puts the settings and metadata in the specified RavenDB
try
{

    Invoke-RestMethod -Uri $putSettingsURI -Headers $metadata -Body $allSettingsJSON -Method Put
        
    Write-Output "New settings have been successfully added to the database"
}
catch
{
    Write-Error "An error occurred while inserting the new settings document to the database" -ErrorId E4
} 

