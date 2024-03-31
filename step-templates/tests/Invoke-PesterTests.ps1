$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);
$rootFolder = [System.IO.Path]::GetDirectoryName($thisFolder);
$parentFolder = [System.IO.Path]::GetDirectoryName($rootFolder);

# Unpack any tests that are not present
$testableScripts = Get-ChildItem -Path $thisFolder -Filter "*.ScriptBody.ps1"
foreach ($script in $testableScripts) {
    $filename = [System.IO.Path]::Combine($rootFolder, $script.Name)
    if (-not [System.IO.File]::Exists($filename)) {
        $searchpattern = $script.BaseName -replace "\.ScriptBody$"
        $toolsFolder = [System.IO.Path]::Combine($parentFolder, "tools")
        $converter = [System.IO.Path]::Combine($toolsFolder, "Converter.ps1")
        & $converter -operation unpack -searchpattern $searchpattern
    }
    . $filename;
}

# Attempt to use local Pester module, fallback to global if not found
try {
    $packagesFolder = [System.IO.Path]::Combine($rootFolder, "packages")
    $pester3Path = [System.IO.Path]::Combine($packagesFolder, "Pester\tools\Pester")
    # Import the specific version of Pester 3.4.0
    Import-Module -Name $pester3Path -RequiredVersion 3.4.0 -ErrorAction Stop
} catch {
    Write-Host "Using globally installed Pester module version 3.4.0."
    # Specify the exact version of Pester 3.x you have installed
    Import-Module -Name Pester -RequiredVersion 3.4.0 -ErrorAction Stop}

# Find and run all Pester test files in the tests directory
$testFiles = Get-ChildItem -Path "$thisFolder" -Filter "*.tests.ps1" -Recurse
foreach ($testFile in $testFiles) {
    Write-Host "Running tests in: $($testFile.FullName)"
    Invoke-Pester -Path $testFile.FullName
}
