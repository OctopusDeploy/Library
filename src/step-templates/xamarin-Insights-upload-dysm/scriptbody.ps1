#####################################
# Xamarin Insights dSYM Upload script
#
# Uploads a dSYM sybmols file to Xamarin insights from a Nuget file
#  extracted in a previous Octopus Deploy step. Allows a variety of parameters.
#
# Uploads to configured application, by API Key.
#
# API Documentation is available at: https://developer.xamarin.com/guides/insights/user-interface/settings/#Uploading_a_dSYM_File
#
# The API key involved is provided in the "Settings" for the particular app on the Xamarin Insights portal.
# https://insights.xamarin.com/
# Log in, open the application, and click settings. The general "settings" tab has the API Key field.
#
# Example curl request:
# curl -F "dsym=@YOUR-APPS-DSYM.zip;type=application/zip" https://xaapi.xamarin.com/api/dsym?apikey=13dd6c82159361ea13ad25a0d9100eb6e228bb17
#
# v0.1 - Initial version, uploads one dSYM file.
# 
# The nuget package must contain the *.app.dSYM.zip file.  
#
# The following *.nuspec example will package a release IPA and associated *.app.dSYM.zip file.
#
# The upload script requires a search path (default package root) with exactly one *.app.dSYM.zip file.
# 
# Specify package path relative to the nuspec file location
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
        
        <!-- iOS -->
        <file src="**/Release/**/*.ipa" target="" />

        <!-- Include release dSYM symbols file -->
        <file src="**/Release/*.app.dSYM.zip" target="" />

      </files>
    </package>

#>

#############################
# Debug Parameter Overrides #
#############################

# These values are set explicitly durring debugging so that the script can
#   be run in the editor.
# For local debugging, uncomment these values and fill in appropriately.

<#

# debug folder with app files
$stepPath = "C:\Temp\powershellscript\"

$OctopusParameters = @{
"InsightsAppSpecificApiToken" = "YourApiKeyhere";
# "NugetSearchPath" = "bin\iPhone"; # Additional path information, reatlive to the nuget file root, e.g. release
}

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

function Get-ExactlyOneDsymFileInfo($searchPath)
{
    $symbolFiles = Get-ChildItem -Path $searchPath -Recurse -Filter *.app.dSYM.zip
    
    $fileCount = $symbolFiles.count

    if($fileCount -ne 1)
    {
        throw "Did not find exactly one (1) symbols file. Found $fileCount dSYM file(s). Searched under path: $searchPath"
    }

    return $symbolFiles
}

####################
# Basic Parameters #
####################

$apiToken = $OctopusParameters['InsightsAppSpecificApiToken']

$octopusFilePathOverride = $OctopusParameters['NugetSearchPath']

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

Write-Host "##octopus[stderr-progress]"

# if we were not provided a file name, search for a single package file
if([string]::IsNullOrWhiteSpace($octopusFilePathOverride))
{
    $appFileInfo = Get-ExactlyOneDsymFileInfo $stepPath
    $appFullFilePath = $appFileInfo.FullName
}
else
{
    $searchPathOverride = Join-Path $stepPath $octopusFilePathOverride
    $appFileInfo = Get-ExactlyOneDsymFileInfo $searchPathOverride
    $appFullFilePath = $appFileInfo.FullName
}

$fileName = [System.IO.Path]::GetFileName($appFullFilePath)

$apiUploadUri = "https://xaapi.xamarin.com/api/dsym?apikey=$apiToken"

# Request token details
$uniqueBoundaryToken = [Guid]::NewGuid().ToString()

$contentType = "multipart/form-data; boundary=$uniqueBoundaryToken"


Write-Host "File Location: $appFullFilePath"

################################
# Set up Hockey App parameters #
################################

$formSectionSeparator = @"

--$uniqueBoundaryToken

"@

############################
# Prepare request wrappers #
############################

# Standard for multipart form data
# http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4

$stringEncoding = [System.Text.Encoding]::ASCII

# Note the hard-coded "ipa" name here is per HockeyApp API documentation
#  and it applies to ALL platform application files.

$preFileBytes = $stringEncoding.GetBytes(
$formSectionSeparator +
@"
Content-Disposition: form-data; name="dsym"; filename="$fileName"
Content-Type: application/zip


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
