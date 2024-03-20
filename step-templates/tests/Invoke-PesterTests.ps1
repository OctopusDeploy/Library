$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);
$rootFolder = [System.IO.Path]::GetDirectoryName($thisFolder);

$testableScripts = @(
    "windows-scheduled-task-create.ScriptBody.ps1",
    "sql-backup-database.ScriptBody.ps1"
);

foreach( $script in $testableScripts )
{
    $filename = [System.IO.Path]::Combine($rootFolder, $script);
    if( -not [System.IO.File]::Exists($filename) )
    {
        throw new-object System.IO.FileNotFoundException("Testable script not found.", $filename);
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
