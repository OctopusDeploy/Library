Import-Module "WebAdministration" -ErrorAction Stop

function SetIisLogPath {
    param($logPath, $IISsitename)
    write-host "#Updating IIS Log path"
    
    if (!(Test-Path "IIS:\Sites\$($IISsitename)")) {
        write-host "$IISsitename does not exist in IIS"
    } else {
        Set-ItemProperty IIS:\Sites\$($IISsitename) -name logFile.directory -value $logPath
        write-host "IIS LogPath updated to $logPath"
    }
}

function AdvancedLogging-GenerateAppCmdScriptToConfigureAndRun
{
    param([string] $site) 

    #Clear existing log definition if it exists. We use site name to make it apparent where it belongs.
    clear-WebConfiguration -PSPath IIS:\ -Filter "system.webServer/advancedLogging/server/logDefinitions/logDefinition[@baseFileName='$site']"

    #Get current powershell execution folder
    $currentLocation = Get-Location

    #Create an empty bat which will be populated with appcmd instructions
    $stream = [System.IO.StreamWriter] "$currentLocation\$site.bat"

    $stream.WriteLine("%systemroot%\system32\inetsrv\appcmd.exe clear config ""$site"" -section:system.webServer/advancedLogging/server /commit:apphost")

    #Create site specific log definition
    $stream.WriteLine("%systemroot%\system32\inetsrv\appcmd.exe set config ""$site"" -section:system.webServer/advancedLogging/server /+`"logDefinitions.[baseFileName='$site',enabled='True',logRollOption='Schedule',schedule='Daily',publishLogEvent='False']`" /commit:apphost")

    #Get all available fields for logging
    $availableFields = Get-WebConfiguration "system.webServer/advancedLogging/server/fields"

    $targetFields = ((GetIisLogFields).iisHeader)
    Write-Host "Target fields: " (($targetFields) -join ',')
    #Add appcmd instruction to add all the selected fields above to be logged as part of the logging
    #The below section can be extended to filter out any unwanted fields
    foreach ($field in $targetFields) {
    	$f = (($availableFields.Collection) |Where-Object {$_.logHeaderName -eq "$field"})
    	Write-Host "Appending " $f.iisHeader $f.id
        $stream.WriteLine("C:\windows\system32\inetsrv\appcmd.exe set config ""$site"" -section:system.webServer/advancedLogging/server /+`"logDefinitions.[baseFileName='$site'].selectedFields.[id='$($f.id)',logHeaderName='$($f.logHeaderName)']`" /commit:apphost")
    }

    $stream.close()

    # execute the batch file create to configure the site specific Advanced Logging
    Start-Process -FilePath $currentLocation\$site.bat
    Start-Sleep -Seconds 10
}

function GetIisLogFields {
    $IisLogFields = @()
    if ($OctopusParameters['Date'] -eq "True") 		    { $IisLogFields += New-Object PSObject -Property @{id = "Date"; iisHeader = "date" } }
    if ($OctopusParameters['Time'] -eq "True") 		    { $IisLogFields += New-Object PSObject -Property @{id = "Time"; iisHeader = "time" } }
    if ($OctopusParameters['ClientIP'] -eq "True")      	{ $IisLogFields += New-Object PSObject -Property @{id = "ClientIP"; iisHeader = "c-ip"} }
    if ($OctopusParameters['UserName'] -eq "True")     	{ $IisLogFields += New-Object PSObject -Property @{id = "UserName"; iisHeader = "cs-username" } }
    if ($OctopusParameters['SiteName'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "SiteName"; iisHeader = "s-sitename" } }
    if ($OctopusParameters['ComputerName'] -eq "True")     { $IisLogFields += New-Object PSObject -Property @{id = "ComputerName"; iisHeader = "s-computername" } }
    if ($OctopusParameters['ServerIP'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "ServerIP"; iisHeader = "s-ip" } }
    if ($OctopusParameters['ServerPort'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "ServerPort"; iisHeader = "s-port" } }
    if ($OctopusParameters['Method'] -eq "True")    		{ $IisLogFields += New-Object PSObject -Property @{id = "Method"; iisHeader = "cs-method" } }
    if ($OctopusParameters['UriStem'] -eq "True") 	    	{ $IisLogFields += New-Object PSObject -Property @{id = "UriStem"; iisHeader = "cs-uri-stem" } }
    if ($OctopusParameters['UriQuery'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "UriQuery"; iisHeader = "cs-uri-query" } }
    if ($OctopusParameters['HttpStatus'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "HttpStatus"; iisHeader = "sc-status" } }
    if ($OctopusParameters['HttpSubStatus'] -eq "True") 	{ $IisLogFields += New-Object PSObject -Property @{id = "HttpSubStatus"; iisHeader = "sc-substatus" } }
    if ($OctopusParameters['Win32Status'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "Win32Status"; iisHeader = "sc-win32-status" } }
    if ($OctopusParameters['BytesSent'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "BytesSent"; iisHeader = "sc-bytes" } }
    if ($OctopusParameters['BytesRecv'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "BytesRecv"; iisHeader = "cs-bytes" } }
    if ($OctopusParameters['TimeTaken'] -eq "True")     	{ $IisLogFields += New-Object PSObject -Property @{id = "TimeTaken"; iisHeader = "TimeTakenMS" } }
    if ($OctopusParameters['ProtocolVersion'] -eq "True") 	{ $IisLogFields += New-Object PSObject -Property @{id = "ProtocolVersion"; iisHeader = "cs-version" } }
    if ($OctopusParameters['Host'] -eq "True") 		    { $IisLogFields += New-Object PSObject -Property @{id = "Host"; iisHeader = "cs(Host)" } }
    if ($OctopusParameters['UserAgent'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "UserAgent"; iisHeader = "cs(User-Agent)" } }
    if ($OctopusParameters['Cookie'] -eq "True")    		{ $IisLogFields += New-Object PSObject -Property @{id = "Cookie"; iisHeader = "cs(Cookie)" } }
    if ($OctopusParameters['Referer'] -eq "True") 		    { $IisLogFields += New-Object PSObject -Property @{id = "Referer"; iisHeader = "cs(Referer)" } }
    if ($OctopusParameters['OriginalIP'] -eq "True") 	    { $IisLogFields += New-Object PSObject -Property @{id = "OriginalIP"; iisHeader = "x-forwarded-for" } }
    return $IisLogFields    
}

function SetForIISAboveV7 {
    param($SiteName)
    [System.Collections.ArrayList]$logFields = ((GetIisLogFields).id)
    $filter = "/system.applicationHost/sites/site[@Name=""$SiteName""]/logFile"
    write-host "Filter: $filter"
    
    #Clear all existing custom fields...
    clear-WebConfiguration -PSPath IIS:\ -Filter "$filter/customFields"
    
    if ($logFields.Contains("OriginalIP")) { 
      add-WebConfiguration -PSPath IIS:\ -Filter "$filter/customFields" -Value @{logFieldName='OriginalIP';sourceType='RequestHeader';sourceName='X-FORWARDED-FOR'}
    }
    
    Write-Host (($logFields) -join ',')
    # This is part of extended logging and cannot be set using the syntax below.
    $logFields.Remove("OriginalIP")
    Set-WebConfigurationProperty -Filter $filter -Value (($logFields) -join ',') -Name "LogExtFileFlags"
}

function SetForIISV7 {
    param($site, $logDirectory)
    Write-Host 'Disables http logging module'
    Set-WebConfigurationProperty -Filter system.webServer/httpLogging -PSPath machine/webroot/apphost -Name dontlog -Value true
    Write-Host 'Adding X-Forwarded-For as OriginalIP to advanced logging'
    if (Get-WebConfigurationProperty "system.webServer/advancedLogging/server/fields" -Name Collection |Where-Object {$_.id -eq "OriginalID"}) {
	write-host "OriginalID field already exists. Will not modify existing definition."
    } else {
        Add-WebConfiguration "system.webServer/advancedLogging/server/fields" -value @{id="OriginalID";sourceName="X-Forwarded-For";sourceType="RequestHeader";logHeaderName="X-Forwarded-For";category="Default";loggingDataType="TypeLPCSTR"}
    }
    # Disables the default advanced logging config
    Set-WebConfigurationProperty -Filter "system.webServer/advancedLogging/server/logDefinitions/logDefinition[@baseFileName='%COMPUTERNAME%-Server']" -name enabled -value false
    # Enable Advanced Logging
    Set-WebConfigurationProperty -Filter system.webServer/advancedLogging/server -PSPath machine/webroot/apphost -Name enabled -Value true
    
    # Set log directory at server level
    Set-WebConfigurationProperty -Filter system.applicationHost/advancedLogging/serverLogs -PSPath machine/webroot/apphost -Name directory -Value $logDirectory
    
    # Set log directory at site default level
    Set-WebConfigurationProperty -Filter system.applicationHost/sites/siteDefaults/advancedLogging -PSPath machine/webroot/apphost -Name directory -Value $logDirectory	

    AdvancedLogging-GenerateAppCmdScriptToConfigureAndRun $site	
}

Write-Host "Value of UriQuery parameter " $OctopusParameters['UriQuery']
$logPath = $OctopusParameters['IISLogPath']
$IISsitename = $OctopusParameters['webSiteName']
$iisMajorVersion = (get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\ |select MajorVersion).MajorVersion
if ($iisMajorVersion -gt 7) {
  SetForIISAboveV7 $OctopusParameters['SiteName'] 
  SetIisLogPath $OctopusParameters['iisLogDirectory'] $OctopusParameters['SiteName']
} elseif ($iisMajorVersion -lt 7) {
   Write-Host 'Cannot handle IIS versions below 7. Found IIS version ' $iisMajorVersion
   exit 1
} else {
    SetForIISV7 $OctopusParameters['SiteName'] $OctopusParameters['iisLogDirectory']
}

