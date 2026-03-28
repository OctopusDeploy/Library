#####################################
# Xamarin TestCloud Start Test Run script
# 
# Kicks off a new test run for an app.
# This script uses the test-cloud.exe helper utility included with the Xamarin UITest nuget package. 
# https://www.nuget.org/packages/Xamarin.UITest
# 
# For use with Xamarin UITests
# https://developer.xamarin.com/guides/testcloud/uitest/
# being run in Xamarin TestCloud on physical devices
# https://developer.xamarin.com/guides/testcloud/introduction-to-test-cloud/
#
# v0.1 - kicks off configured test run, tested against iOS app only
#
# The nuget package must contain the *.iap or *.apk file, compiled with calabash included
# The nuget package must contain the DLLs from the UITest project
# The nuget package may optionally contain a symbols file, *.app.dSYM.zip
# The nuget package must contain the test-cloud.exe support utility
#
# The following *.nuspec example will package:
# * a release ipa
# * UITest DLLs
# * associated *.app.dSYM.zip file
# * The test-cloud.exe support utility
#
# all search paths default to the root of the nuget package,
# and may be further qualified relative to the root of the nuget package
# The upload script uses default or optionally qualified search paths for the following:
# * The .ipa or .apk location
# * The UITest project DLLs
# * The *.app.dSYM.zip symbols file
# * The test-cloud.exe utility
#
# It also requires the API Key from the application, and the code for the devices desired,
# and a valid user accout to run as.
#
# 1. Visit the testcloud interface: https://testcloud.xamarin.com/
# 2. Choose "New Test Run" and configure as desired.
# 3. In the last step, copy the large hash (app specific API Key), devices parameter code, and username
#
# The nugetFile below is an example that retrieves the appropriate files from a typical iOS build
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

        <!-- UITest DLLs -->
        <file src="..\*Test*\bin\Release\*.dll" target="bin/UITest/Release" />

        <!-- Utility EXE for TestCloud submission scripts -->
        <!-- Note: The first slash after the parent directory .. MUST be backslash or the package step fails -->
        <file src="..\packages/Xamarin.UITest.*/tools/test-cloud.exe" target="tools" />

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

$OctopusParameters = @{
"appPathOverride" = "" # "bin\iPhone"
"dllPathOverride" = "" # "bin\UITest\Release"
"testCloudUserName" = "your.user@name.com"
"symbolPathOverride" = ""; # "bin\iPhone"
"apiKey" = "YOUR-KEY-HERE";
"devicesCode" = "ae978982"; # devices code here (example ae978982 is 2 devices)
"series" = "master"; # default is master
"locale" = "en_US"; # default locale is en_US
"testCloudExePathOverride" = "" # "tools"
}

# debug folder with app files
$stepPath = "C:\Temp\powershellscript\"

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
        throw "Did not find exactly one (1) mobile application package. Found $apkCount APK file(s), $ipaCount IPA file(s), and $appxCount Appx file(s). Searched under path: $searchPath"
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

function Get-OneDsymFileInfoOrNull($searchPath)
{
    $symbolFiles = Get-ChildItem -Path $searchPath -Recurse -Filter *.app.dSYM.zip
    
    $fileCount = $symbolFiles.count

    if($fileCount -eq 0)
    { 
        return $null
    }   

    if($fileCount -gt 1)
    {
        throw "Found more than one symbols file. Found $fileCount dSYM file(s). Searched under path: $searchPath"
    }

    return $symbolFiles
}

function Get-ExactlyOneUploadExeFileInfo($searchPath)
{
    $testcloudexefiles = Get-ChildItem -Path $searchPath -Recurse -Filter test-cloud.exe
    
    $fileCount = $testcloudexefiles.count

    if($fileCount -ne 1)
    {
        throw "Did not find exactly one (1) test-cloud.exe. Found $fileCount exe file(s). Searched under path: $searchPath"
    }

    return $testcloudexefiles
}

function Get-ExactlyOneUITestDllPath($searchPath)
{
    $XamarinUITestdlls = Get-ChildItem -Path $searchPath -Recurse -Filter Xamarin.UITest.dll
    
    $fileCount = $XamarinUITestdlls.count

    if($fileCount -ne 1)
    {
        throw "Did not find exactly one (1) Test DLL location. Found $fileCount DLL location(s), based on finding 'Xamarin.UITest.dll' files. Searched under path: $searchPath"
    }
    
    $singleXamarinUITestDllFullPath = $XamarinUITestdlls.FullName
    $UITestDllPath = Split-Path -parent $singleXamarinUITestDllFullPath
    return $UITestDllPath
}

####################
# Basic Parameters #
####################

# required
$apiKey = $OctopusParameters['apiKey']
$devicesCode = $OctopusParameters['devicesCode']
$testCloudUserName = $OctopusParameters['testCloudUserName']

# optional
$series = $OctopusParameters['series'] # default "master"
$locale = $OctopusParameters['locale'] # default "en_US"

# optional additional path overrides
$appPathOverride = $OctopusParameters['appPathOverride']
$dllPathOverride = $OctopusParameters['dllPathOverride']
$symbolPathOverride = $OctopusParameters['symbolPathOverride']
$testCloudExePathOverride = $OctopusParameters['testCloudExePathOverride']

# test cloud user names must be lower case to work around API/Utility issue (until issue is fixed)
$testCloudUserName = $testCloudUserName.ToLower()

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

Write-Host "Nuget Package base path    : $stepPath"
# Write-Host "##octopus[stderr-progress]"

# find app

# complete search paths, overrides may be blank
$appSearchPath = Join-Path $stepPath $appPathOverride
$symbolSearchPath = Join-Path $stepPath $symbolPathOverride
$dllSearchPath = Join-Path $stepPath $dllPathOverride
$testCouldExeSearchPath = Join-Path $stepPath $testCloudExePathOverride

$appFileFullPath = (Get-ExactlyOneMobilePackageFileInfo $appSearchPath).FullName
$symbolFileFullPath = (Get-OneDsymFileInfoOrNull $symbolSearchPath).FullName
$dllDirectoryFullPath = Get-ExactlyOneUITestDllPath $dllSearchPath

$testCloudExeFullPath = (Get-ExactlyOneUploadExeFileInfo $testCouldExeSearchPath).FullName

# It turns out that the utility exe expects a dsym folder, convert to folder

# DIRTY HACKS - the API should accept a *.dSYM.zip like insights does, see
# https://testcloud.ideas.aha.io/ideas/XTA-I-50

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

$symbolFileDirectoryPath = ""
if($symbolFileFullPath) # has a full zip path
{
    $parentPath = Split-Path -parent $symbolFileFullPath
    Unzip $symbolFileFullPath $parentPath

    # get unzipped folder name ending in dSYM
    $symbolFileDirectoryPath = (Get-ChildItem -Path $parentPath -Recurse -Filter *.dSYM).FullName
}
elseif ($symbolPathOverride) # no zip, try to find folder
{
    # search for dSYM folder instead

    $symbolFileDirectorySearchResults = Get-ChildItem -Path $searchPath -Recurse -Filter *.dSYM
    
    # if exactly one result
    if($symbolFileDirectorySearchResults.Count -eq 1)
    {
        $symbolFileDirectoryPath = $symbolFileDirectorySearchResults.FullName
    }
}

######################
# Invoke the request #
######################
 
Write-Host "App path                   : " $appFileFullPath
Write-Host "Symbol File path (optional): " $symbolFileFullPath
Write-Host "Test DLL full path         : " $dllDirectoryFullPath
Write-Host "TestCloud exe path         : " $testCloudExeFullPath
Write-Host

# run command with optional argument

if($symbolFileDirectoryPath) # symbols file present
{
    Write-Host "Running command: " 
    Write-Host """$testCloudExeFullPath"" submit ""$appFileFullPath"" $apiKey --user $testCloudUserName --devices $devicesCode --series ""$series"" --locale ""$locale"" --assembly-dir ""$dllDirectoryFullPath"" --dsym ""$symbolFileDirectoryPath"""
    Write-Host 
    cmd /c "$testCloudExeFullPath" submit "$appFileFullPath" $apiKey --user $testCloudUserName --devices $devicesCode --series "$series" --locale "$locale" --assembly-dir "$dllDirectoryFullPath" --dsym "$symbolFileDirectoryPath"
}
else # no symbols file
{
    Write-Host "Running command: " 
    Write-Host """$testCloudExeFullPath"" submit ""$appFileFullPath"" $apiKey --user $testCloudUserName --devices $devicesCode --series ""$series"" --locale ""$locale"" --assembly-dir ""$dllDirectoryFullPath"""
    Write-Host
    cmd /c "$testCloudExeFullPath" submit "$appFileFullPath" $apiKey --user $testCloudUserName --devices $devicesCode --series "$series" --locale "$locale" --assembly-dir "$dllDirectoryFullPath"
}

Write-Host
Write-Host "TestCloud upload command complete."