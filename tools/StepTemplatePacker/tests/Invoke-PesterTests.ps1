param(
    [string] $Filter = "*"
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $thisFolder ".." ".." ".."));
$packer = [System.IO.Path]::GetDirectoryName($thisFolder);
$sharedRunner = Join-Path $repoRoot "tools" "Invoke-SharedPesterTests.ps1";

& $sharedRunner `
    -TestRoot $thisFolder `
    -Filter $Filter `
    -ImportModules @($packer);
