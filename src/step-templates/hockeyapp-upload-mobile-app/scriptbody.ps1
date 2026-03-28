# Hockey App Upload script
#
# Uploads a mobile platform application package to Hockey App from a Nuget file
#  extracted in a previous Octopus Deploy step. Allows a variety of parameters.
#
# v0.5 - Turns out Invoke-WebRequest was a memory hog, casuing high memory usage and
#         out-of-memory errors. Switched to dot net native web request and streams.
# v0.4 - Package location search is now recursive, as required by *.nuspec example.
#        Added default description to pass along nuget version to notes.
# v0.3 - Now supports windows .appx packages
# v0.2 - Added extra parameters
# v0.1 - Initial version, basic upload
# 
#
# The following *.nuspec example will package ALL matching Ipa, Apk (signed), and Appx files.
# The upload script requires exactly one match (or specifying the exact file)
# 
# Specify specific package path relative to the nuspec file location (or overriden basepath)
#
# https://docs.nuget.org/create/nuspec-reference#file-element-examples
#
# In some cases the ID, Version, and Description may need manually specified.
#

<#

    <?xml version="1.0"?>
    <package>
      <metadata>
        <id>$id$</id>
        <title>$id$</title>
        <version>$version$</version>
        <description>Mobile project packaged for Octopus deploy. $description$</description>
      </metadata>
      <files>
        <!-- Matches mobile package files. Note this will only include the platform being built,
	         and should match only a single file. -->

        <!-- Android, Signed only -->
        <file src="**/Release/**/*-Signed.apk" target="" />

        <!-- iOS -->
        <file src="**/Release/**/*.ipa" target="" />

        <!-- Windows App -->
        <file src="**/*.appx" exclude="**/Dependencies/**" target="" />
      </files>
    </package>

#>

# Hockey App API reference
#
# General API reference: http://support.hockeyapp.net/kb/api
# Auth reference (tokens): http://support.hockeyapp.net/kb/api/api-basics-and-authentication
# Upload App Version reference: http://support.hockeyapp.net/kb/api/api-versions#upload-version

#############################
# Debug Parameter Overrides #
#############################

# These values are set explicitly durring debugging so that the script can
#   be run in the editor.
# For local debugging, uncomment these values and fill in appropriately.

<#

$OctopusParameters = @{
"HockeyAppApiToken" = "YourApiKeyhere";
"HockeyAppAppID" = "YourAppIdHere";
"PackageFileName" = "MyAppFile-1.2.3.4.ipa"; # app file name
"HockeyAppNotify" = "1";
"HockeyAppStatus" = "2";
}

# debug folder with app files
$stepPath = "C:\Temp\HockeyAppScript\"


# #>

###################################
# Octopus Deploy common functions #
###################################

# A collection of functions that can be used by script steps to determine where packages installed
# by previous steps are located on the filesystem.
 
function Find-InstallLocations {
    $result = @()
    $OctopusParameters.Keys | foreach {
        if ($_.EndsWith('].Output.Package.InstallationDirectoryPath')) {
            $result += $OctopusParameters[$_]
        }
    }
    return $result
}
 
function Find-InstallLocation($stepName) {
    $result = $OctopusParameters.Keys | where {
        $_.Equals("Octopus.Action[$stepName].Output.Package.InstallationDirectoryPath",  [System.StringComparison]::OrdinalIgnoreCase)
    } | select -first 1
 
    if ($result) {
        return $OctopusParameters[$result]
    }
 
    throw "No install location found for step: $stepName"
}

function Find-SingleInstallLocation {
    $all = @(Find-InstallLocations)
    if ($all.Length -eq 1) {
        return $all[0]
    }
    if ($all.Length -eq 0) {
        throw "No package steps found"
    }
    throw "Multiple package steps have run; please specify a single step"
}

#####################
# Utility functions #
#####################

function Get-ExactlyOneMobilePackageFileInfo($searchPath)
{
    $apkFiles = Get-ChildItem -Path $searchPath -Recurse -Filter *.apk #Android
    $ipaFiles = Get-ChildItem -Path $searchPath -Recurse -Filter *.ipa #iOS
    $appxFiles = Get-ChildItem -Path $searchPath -Recurse -Filter *.appx # windows

    $apkCount = $apkFiles.count

    $ipaCount = $ipaFiles.count

    $appxCount = $appxFiles.count

    $totalCount = $apkCount + $ipaCount + $appxCount

    if($totalCount -ne 1)
    {
        throw "Did not find exactly one (1) mobile application package. Found $apkCount APK file(s), $ipaCount IPA file(s), and $appxCount Appx file(s)."
    }

    if($apkCount -eq 1)
    {
        return $apkFiles
    }

    if($ipaCount -eq 1)
    {
        return $ipaFiles
    }

    if($appxCount -eq 1)
    {
        return $appxFiles
    }

    throw "Unable to find mobile application packages (fallback error - not expected)"
}

function AddToHashIfExists([HashTable]$table, $value, $name)
{
    if(-not [String]::IsNullOrWhiteSpace($value))
    {
        $table.Add($name, $value)
    }
}

function GetMultipartFormSectionString($key,$value)
{
    return @"
Content-Disposition: form-data; name="$key"

$value
"@
}

####################
# Basic Parameters #
####################

$apiToken = $OctopusParameters['HockeyAppApiToken']
$appId = $OctopusParameters['HockeyAppAppID']

$octopusFilePathOverride = $OctopusParameters['PackageFileName']

$stepName = $OctopusParameters['MobileAppPackageStepName']

# set step path, if not already set
If([string]::IsNullOrEmpty($stepPath))
{
    if (![string]::IsNullOrEmpty($stepName)) {
        Write-Host "Finding path to package step: $stepName"
        $stepPath = Find-InstallLocation $stepName
    } else {
        $stepPath = Find-SingleInstallLocation
    }
}

Write-Host "Package is located in folder: $stepPath"
Write-Host "##octopus[stderr-progress]"

# if we were not provided a file name, search for a single package file
if([string]::IsNullOrWhiteSpace($octopusFilePathOverride))
{
    $appFileInfo = Get-ExactlyOneMobilePackageFileInfo $stepPath
    $appFullFilePath = $appFileInfo.FullName
}
else
{
    $appFullFilePath = Join-Path $stepPath $octopusFilePathOverride
}

$fileName = [System.IO.Path]::GetFileName($appFullFilePath)

$apiUploadUri = "https://rink.hockeyapp.net/api/2/apps/$appId/app_versions/upload"

# Request token details
$uniqueBoundaryToken = [Guid]::NewGuid().ToString()

$contentType = "multipart/form-data; boundary=$uniqueBoundaryToken"

################################
# Set up Hockey App parameters #
################################

$HockeyAppParameters = @{} # parameters are a hash table.

# add parameters that have values - See docs at http://support.hockeyapp.net/kb/api/api-versions#upload-version

AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppNotes']          "notes"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppNotesType']      "notes_type"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppNotify']         "notify"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppStatus']         "status"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppTags']           "tags"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppTeams']          "teams"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppUsers']          "users"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppMandatory']      "mandatory"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppCommitSha']      "commit_sha"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppBuildServerUrl'] "build_server_url"
AddToHashIfExists $HockeyAppParameters $OctopusParameters['HockeyAppRepositoryUrl']  "repository_url"

$formSectionSeparator = @"

--$uniqueBoundaryToken

"@

if($HockeyAppParameters.Count -gt 0)
{
    $parameterSectionsString = [String]::Join($formSectionSeparator,($HockeyAppParameters.GetEnumerator() | %{GetMultipartFormSectionString $_.Key $_.Value}))
}

############################
# Prepare request wrappers #
############################

# Standard for multipart form data
# http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4

$stringEncoding = [System.Text.Encoding]::ASCII

# Note the hard-coded "ipa" name here is per HockeyApp API documentation
#  and it applies to ALL platform application files.

$preFileBytes = $stringEncoding.GetBytes(
$parameterSectionsString + 
$formSectionSeparator +
@"
Content-Disposition: form-data; name="ipa"; filename="$fileName"
Content-Type: application/octet-stream


"@)

# file bytes will go in between

$postFileBytes = $stringEncoding.GetBytes(@"

--$uniqueBoundaryToken--
"@)

######################
# Invoke the request #
######################

# Note, previous approach was Invoke-RestMethod based. It worked, but was NOT memory
# efficient, leading to high memory usage and "out of memory" errors.

# Based on examples from
# http://stackoverflow.com/questions/566462/upload-files-with-httpwebrequest-multipart-form-data
# and 
# https://gist.github.com/nolim1t/271018

# Uses a dot net WebRequest and streaming to limit memory usage

$WebRequest = [System.Net.WebRequest]::Create("$apiUploadUri")

$WebRequest.ContentType = $contentType
$WebRequest.Method = "POST"
$WebRequest.KeepAlive = $true;
$WebRequest.Headers.Add("X-HockeyAppToken",$apiToken)

$RequestStream = $WebRequest.GetRequestStream()

# before file bytes
$RequestStream.Write($preFileBytes, 0, $preFileBytes.Length);

#files bytes

$fileMode = [System.IO.FileMode]::Open
$fileAccess = [System.IO.FileAccess]::Read

$fileStream = New-Object IO.FileStream $appFullFilePath,$fileMode,$fileAccess
$bufferSize = 4096 # 4k at a time
$byteBuffer = New-Object Byte[] ($bufferSize)

# read bytes. While bytes are read...
while(($bytesRead = $fileStream.Read($byteBuffer,0,$byteBuffer.Length)) -ne 0)
{
    # write those byes to the request stream
    $RequestStream.Write($byteBuffer, 0, $bytesRead)
}

$fileStream.Close()

# after file bytes
$RequestStream.Write($postFileBytes, 0, $postFileBytes.Length);

$RequestStream.Close()

$response = $WebRequest.GetResponse();
