param(
    [Parameter(Mandatory = $true)]
    [string] $TestRoot,
    [string] $Filter = "*",
    [scriptblock] $BeforeRun,
    [string[]] $ImportModules = @(),
    [switch] $UsePassThruFailureCheck,
    [string] $PreferredPesterVersion,
    [string] $SuiteName = "tests"
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$testRootPath = [System.IO.Path]::GetFullPath($TestRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$originalSystemRoot = $env:SystemRoot
$originalTemp = $env:TEMP

function Get-PesterModuleSpec {
    $packagesFolder = Join-Path $repoRoot "packages"
    $attempts = @()
    $localPesterPaths = @()

    if ($PreferredPesterVersion) {
        $localPesterPaths += (Join-Path $packagesFolder ("Pester.{0}" -f $PreferredPesterVersion) "tools" "Pester")
    }
    $localPesterPaths += (Join-Path $packagesFolder "Pester" "tools" "Pester")

    foreach ($localPesterPath in $localPesterPaths | Select-Object -Unique) {
        $attempts += $localPesterPath
        if (Test-Path -Path $localPesterPath) {
            $localManifestPath = Join-Path $localPesterPath "Pester.psd1"
            $modulePath = $localPesterPath
            if (Test-Path -Path $localManifestPath) {
                $modulePath = $localManifestPath
            }

            $module = Test-ModuleManifest -Path $modulePath -ErrorAction Stop
            if ($module.Version.Major -eq 3 -and ((-not $PreferredPesterVersion) -or $module.Version -eq [version]$PreferredPesterVersion)) {
                return [pscustomobject]@{
                    ModulePath = $module.Path
                    Version = $module.Version.ToString()
                    Source = "repository packages"
                }
            }
        }
    }

    $availablePesterModules = @(Get-Module -ListAvailable Pester | Sort-Object Version -Descending)
    $globalPester = $null

    if ($PreferredPesterVersion) {
        $globalPester = $availablePesterModules | Where-Object { $_.Version -eq [version]$PreferredPesterVersion } | Select-Object -First 1
    }

    if (-not $globalPester) {
        $globalPester = $availablePesterModules | Where-Object { $_.Version.Major -eq 3 } | Select-Object -First 1
    }

    if ($globalPester) {
        return [pscustomobject]@{
            ModulePath = $globalPester.Path
            Version = $globalPester.Version.ToString()
            Source = "installed modules"
        }
    }

    $preferredVersionMessage = if ($PreferredPesterVersion) { "preferred version $PreferredPesterVersion" } else { "a Pester 3.x version" }
    $attemptedPathsMessage = if ($attempts.Count -gt 0) { " Tried package paths: $($attempts -join ', ')." } else { "" }
    throw "Pester $preferredVersionMessage for suite '$SuiteName' was not found in the repository packages folder or installed modules.$attemptedPathsMessage"
}

function Invoke-SelectedTests {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]] $TestFiles
    )

    foreach ($testFile in $TestFiles) {
        Write-Host "Running tests in: $($testFile.FullName)"
        if ($UsePassThruFailureCheck) {
            $result = Invoke-Pester -Path $testFile.FullName -PassThru
            if ($result.FailedCount -gt 0) {
                throw "Tests failed in $($testFile.FullName)."
            }
        } else {
            Invoke-Pester -Path $testFile.FullName
        }
    }
}

try {
    if (-not $env:SystemRoot) {
        $env:SystemRoot = "C:\Windows"
    }
    if (-not $env:TEMP) {
        $env:TEMP = [System.IO.Path]::GetTempPath()
    }

    foreach ($modulePath in $ImportModules) {
        Import-Module -Name $modulePath -ErrorAction Stop
    }

    if ($BeforeRun) {
        & $BeforeRun
    }

    $testFiles = @(Get-ChildItem -Path $testRootPath -Filter "*.tests.ps1" -Recurse)
    if (-not [string]::IsNullOrWhiteSpace($Filter) -and $Filter -ne "*") {
        $testFiles = @($testFiles | Where-Object { $_.Name -like $Filter -or $_.FullName -like $Filter })
    }

    if ($testFiles.Count -eq 0) {
        Write-Host "No matching test files found under $testRootPath for filter '$Filter'."
        return
    }

    if ($PSVersionTable.PSEdition -eq "Core" -and -not $IsWindows) {
        $referenceAssembliesPath = Join-Path $PSHOME "ref"
        if (-not (Test-Path -Path $referenceAssembliesPath)) {
            throw "Pester 3.4.3 on macOS requires a compatible pwsh installation with reference assemblies under '$referenceAssembliesPath'. This runner is intentionally lean and does not patch Pester at runtime."
        }
    }

    $pesterModule = Get-PesterModuleSpec
    Write-Host "Using Pester module version $($pesterModule.Version) from $($pesterModule.Source)."
    Import-Module -Name $pesterModule.ModulePath -RequiredVersion $pesterModule.Version -ErrorAction Stop
    Invoke-SelectedTests -TestFiles $testFiles
} finally {
    $env:SystemRoot = $originalSystemRoot
    $env:TEMP = $originalTemp
}
