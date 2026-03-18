param(
    [Parameter(Mandatory = $true)]
    [string] $TestRoot,
    [string] $Filter = "*",
    [scriptblock] $BeforeRun,
    [string[]] $ImportModules = @(),
    [switch] $UsePassThruFailureCheck
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$testRootPath = [System.IO.Path]::GetFullPath($TestRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$originalSystemRoot = $env:SystemRoot
$originalTemp = $env:TEMP

function Get-PesterModulePath {
    $packagesFolder = Join-Path $repoRoot "packages"
    $localPesterPaths = @(
        (Join-Path $packagesFolder "Pester" "tools" "Pester"),
        (Join-Path $packagesFolder "Pester.3.4.3" "tools" "Pester")
    )

    foreach ($localPesterPath in $localPesterPaths) {
        if (Test-Path -Path $localPesterPath) {
            $localManifestPath = Join-Path $localPesterPath "Pester.psd1"
            if (Test-Path -Path $localManifestPath) {
                return $localManifestPath
            }

            return $localPesterPath
        }
    }

    $globalPester = Get-Module -ListAvailable Pester | Where-Object { $_.Version -eq [version]"3.4.3" } | Select-Object -First 1
    if ($globalPester) {
        return $globalPester.Path
    }

    throw "Pester 3.4.3 was not found in the repository packages folder or installed modules."
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

    Import-Module -Name (Get-PesterModulePath) -RequiredVersion 3.4.3 -ErrorAction Stop
    Invoke-SelectedTests -TestFiles $testFiles
} finally {
    $env:SystemRoot = $originalSystemRoot
    $env:TEMP = $originalTemp
}
