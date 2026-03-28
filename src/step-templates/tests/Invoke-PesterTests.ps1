param(
    [string] $Filter = "*"
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript = $MyInvocation.MyCommand.Path;
$thisFolder = [System.IO.Path]::GetDirectoryName($thisScript);
$rootFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($thisFolder, "..", "..", ".."));
$sourceStepTemplatesFolder = [System.IO.Path]::Combine($rootFolder, "src", "step-templates");
$sharedRunner = Join-Path $rootFolder "tools" "Invoke-SharedPesterTests.ps1"

function Unpack-Scripts-Under-Test {
  $testFiles = Get-ChildItem -Path "$thisFolder" -Filter "*.tests.ps1" -Recurse

  foreach ($testFile in $testFiles) {
      $baseName = $testFile.BaseName -replace "\.ScriptBody.Tests$"
      $scriptFileName = "$baseName.ScriptBody.ps1"
      $scriptFilePath = [System.IO.Path]::Combine($sourceStepTemplatesFolder, $baseName, "scriptbody.ps1")

      # During migration some templates may still be legacy-only. Keep the old unpack flow
      # available until the corresponding source folder exists.
      if (-not [System.IO.File]::Exists($scriptFilePath)) {
          Write-Host "Unpacking legacy script for $($testFile.Name) since $scriptFileName is missing from src..."

          $jsonFileName = "$baseName.json"
          $jsonFilePath = [System.IO.Path]::Combine($rootFolder, "step-templates", $jsonFileName)

          if (-not [System.IO.File]::Exists($jsonFilePath)) {
              throw "JSON file $jsonFileName not found. Cannot unpack script."
          }

          $converter = [System.IO.Path]::Combine($rootFolder, "tools", "Converter.ps1")
          & $converter -operation unpack -searchpattern $baseName

          $legacyScriptPath = [System.IO.Path]::Combine($rootFolder, "step-templates", $scriptFileName)
          if ([System.IO.File]::Exists($legacyScriptPath)) {
              continue
          }

          if (-not [System.IO.File]::Exists($scriptFilePath)) {
              throw "Failed to locate $scriptFileName in src or legacy unpack output. Make sure the JSON template exists and the unpack operation succeeded."
          }
      } else {
          Write-Host "Script $scriptFileName already exists, no need to unpack."
      }
  }
}

& $sharedRunner `
  -TestRoot $thisFolder `
  -Filter $Filter `
  -BeforeRun ${function:Unpack-Scripts-Under-Test} `
  -UsePassThruFailureCheck `
  -PreferredPesterVersion "3.4.0" `
  -SuiteName "step-templates"
