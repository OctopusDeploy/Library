Write-Output "Running xUnit tests with dotnet and vstest..."
$dotNetVer = dotnet --version
Write-Output "DotNet version: $dotNetVer"
$dirPath = $PackageDirectoryPath
$testFiles = $TestPackages
$testFilter = $TestCaseFilter
$xUnitAdditionalParams = $XUnitAdditionalParameters

If(-Not $dirPath){
    Write-Output "Directory with tests is missing!"
    exit 1
}

If(-Not $testFiles){
    Write-Output "Test Package(s) missing!"
    exit 1
}

Write-Output "Execute test package(s): $testFiles"
Write-Output "With following filter(s): $testFilter"
Write-Output "From Package Directory: $dirPath"

cd $dirPath

If($testFilter){
	$runxUnit = "dotnet vstest $testFiles --testcasefilter:'($testFilter)'"
    Write-Output "Run xUnit with filter $testFilter"
    } Else {
    $runxUnit = "dotnet vstest $testFiles"    
    }

if($xUnitAdditionalParams){
	$runxUnit = $runxUnit + " " + $xUnitAdditionalParams
	Write-Output "Run xUnit with Additional Params $xUnitAdditionalParams"
}

Write-Output "Run xUnit with command: $runxUnit"

iex $runxUnit

$xunitExit = $lastExitCode

exit $xunitExit