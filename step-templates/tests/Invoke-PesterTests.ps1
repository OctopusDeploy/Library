$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);
$rootFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($thisFolder, "..", "..")); # Adjust to always point to the root
$testFiles = Get-ChildItem -Path "$thisFolder" -Filter "*.tests.ps1" -Recurse

function Unpack-Scripts-Under-Test {
  foreach ($testFile in $testFiles) {
      $baseName = $testFile.BaseName -replace "\.ScriptBody.Tests$"
      $scriptFileName = "$baseName.ScriptBody.ps1"
      $scriptFilePath = [System.IO.Path]::Combine($rootFolder, "step-templates", $scriptFileName)

      # If the .ps1 file is missing, find the corresponding .json file and unpack it
      if (-not [System.IO.File]::Exists($scriptFilePath)) {
          Write-Host "Unpacking script for $($testFile.Name) since $scriptFileName is missing..."

          $jsonFileName = "$baseName.json"
          $jsonFilePath = [System.IO.Path]::Combine($rootFolder, "step-templates", $jsonFileName)

          if (-not [System.IO.File]::Exists($jsonFilePath)) {
              throw "JSON file $jsonFileName not found. Cannot unpack script."
          }

          $converter = [System.IO.Path]::Combine($rootFolder, "tools", "Converter.ps1")
          & $converter -operation unpack -searchpattern $baseName

          if (-not [System.IO.File]::Exists($scriptFilePath)) {
              throw "Failed to unpack $scriptFileName. Make sure the JSON template exists and the unpack operation succeeded."
          }
      } else {
          Write-Host "Script $scriptFileName already exists, no need to unpack."
      }
  }
}

function Import-Pester {
  # Attempt to use local Pester module, fallback to global if not found
  try {
      $packagesFolder = [System.IO.Path]::Combine($rootFolder, "packages")
      $pester3Path = [System.IO.Path]::Combine($packagesFolder, "Pester\tools\Pester")
      # Import the specific version of Pester 3.4.0
      Import-Module -Name $pester3Path -RequiredVersion 3.4.0 -ErrorAction Stop
  } catch {
      Write-Host "Using globally installed Pester module version 3.4.0."
      # Specify the exact version of Pester 3.x you have installed
      Import-Module -Name Pester -RequiredVersion 3.4.0 -ErrorAction Stop
  }
}

function Run-Tests {
  # Find and run all Pester test files in the tests directory
  foreach ($testFile in $testFiles) {
      Write-Host "Running tests in: $($testFile.FullName)"
      #Invoke-Pester -Path $testFile.FullName
      Invoke-Pester -Script @{Path=$testFile.FullName ; Parameters = @{ Verbose = $True }}
  }
}

Import-Pester
Unpack-Scripts-Under-Test
Run-Tests
