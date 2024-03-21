param(
    [bool]$SkipMissingScripts = $true,
    [bool]$ExpandMissing = $false
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);
$rootFolder = [System.IO.Path]::GetDirectoryName($thisFolder);
$parentFolder = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetDirectoryName($thisFolder));

$testableScripts = @(
    "windows-scheduled-task-create.ScriptBody.ps1",
    "sql-backup-database.ScriptBody.ps1"
);

#unpack any tests that are not present
foreach( $script in $testableScripts )
{
    $filename = [System.IO.Path]::Combine($rootFolder, $script);
    if( -not [System.IO.File]::Exists($filename) )
    {
       $searchpattern = $script -replace "\.ScriptBody\.ps1$";
       $toolsFolder = [System.IO.Path]::Combine($parentFolder, "tools");
       $converter = [System.IO.Path]::Combine($toolsFolder, "Converter.ps1");
       & $converter -operation unpack -searchpattern $searchpattern;
    }
    . $filename;
}

try {
  $packagesFolder = $thisFolder;
  $packagesFolder = [System.IO.Path]::GetDirectoryName($packagesFolder);
  $packagesFolder = [System.IO.Path]::GetDirectoryName($packagesFolder);
  $packagesFolder = [System.IO.Path]::Combine($packagesFolder, "packages");
  Import-Module -Name ([System.IO.Path]::Combine($packagesFolder, "Pester.3.4.3\tools\Pester")) -ErrorAction Stop
} catch {
  Import-Module Pester
}

Invoke-Pester;
