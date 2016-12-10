$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);

$packagesFolder = $thisFolder;
$packagesFolder = [System.IO.Path]::GetDirectoryName($packagesFolder);
$packagesFolder = [System.IO.Path]::GetDirectoryName($packagesFolder);
$packagesFolder = [System.IO.Path]::GetDirectoryName($packagesFolder);
$packagesFolder = [System.IO.Path]::Combine($packagesFolder, "packages");

$packer = [System.IO.Path]::GetDirectoryName($thisFolder);

Import-Module -Name $packer;
Import-Module -Name ([System.IO.Path]::Combine($packagesFolder, "Pester.3.4.3\tools\Pester"));

Invoke-Pester;