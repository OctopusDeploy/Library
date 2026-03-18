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
            return $localPesterPath
        }
    }

    $globalPester = Get-Module -ListAvailable Pester | Where-Object { $_.Version -eq [version]"3.4.3" } | Select-Object -First 1
    if ($globalPester) {
        return $globalPester.ModuleBase
    }

    throw "Pester 3.4.3 was not found in the repository packages folder or installed modules."
}

function Import-PatchedPester {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PesterModulePath
    )

    $patchedPesterPath = Join-Path ([System.IO.Path]::GetTempPath()) ("Pester.3.4.3-pwsh-compatible-{0}" -f ([guid]::NewGuid().ToString("N")))

    Copy-Item -Path $PesterModulePath -Destination $patchedPesterPath -Recurse -Force

    $setupTeardownPath = Join-Path $patchedPesterPath "Functions" "SetupTeardown.ps1"
    $setupTeardown = [System.IO.File]::ReadAllText($setupTeardownPath)

    $addTypePattern = '& \$SafeCommands\[''Add-Type''\] -TypeDefinition @''[\s\S]*?''@\r?\n\r?\n'
    $setupTeardown = [System.Text.RegularExpressions.Regex]::Replace($setupTeardown, $addTypePattern, "", 1)

    $setupTeardown = $setupTeardown.Replace(
        '$closeIndex = [Pester.ClosingBraceFinder]::GetClosingBraceIndex($Tokens, $GroupStartTokenIndex)',
@'
    $groupLevel = 1
    $closeIndex = -1

    for ($i = $GroupStartTokenIndex + 1; $i -lt $Tokens.Length; $i++)
    {
        $type = $Tokens[$i].Type

        if ($type -eq [System.Management.Automation.PSTokenType]::GroupStart)
        {
            $groupLevel++
        }
        elseif ($type -eq [System.Management.Automation.PSTokenType]::GroupEnd)
        {
            $groupLevel--

            if ($groupLevel -le 0)
            {
                $closeIndex = $i
                break
            }
        }
    }
'@)

    [System.IO.File]::WriteAllText($setupTeardownPath, $setupTeardown)

    Remove-Module Pester -ErrorAction SilentlyContinue
    Import-Module -Name (Join-Path $patchedPesterPath "Pester.psd1") -Force -ErrorAction Stop
}

function Import-Pester {
    $pesterModulePath = Get-PesterModulePath

    try {
        Import-Module -Name $pesterModulePath -RequiredVersion 3.4.3 -ErrorAction Stop
    } catch {
        if ($PSVersionTable.PSEdition -eq "Core" -and -not $IsWindows) {
            Write-Host "Importing a patched temporary copy of Pester 3.4.3 for pwsh compatibility."
            Import-PatchedPester -PesterModulePath $pesterModulePath
        } else {
            throw
        }
    }
}

function Get-TestFiles {
    $discoveredFiles = Get-ChildItem -Path $testRootPath -Filter "*.tests.ps1" -Recurse
    if ([string]::IsNullOrWhiteSpace($Filter) -or $Filter -eq "*") {
        return @($discoveredFiles)
    }

    return @(
        $discoveredFiles | Where-Object {
            $_.Name -like $Filter -or $_.FullName -like $Filter
        }
    )
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

    Import-Pester

    if ($BeforeRun) {
        & $BeforeRun
    }

    $testFiles = @(Get-TestFiles)
    if ($testFiles.Count -eq 0) {
        Write-Host "No matching test files found under $testRootPath for filter '$Filter'."
        return
    }

    Invoke-SelectedTests -TestFiles $testFiles
} finally {
    $env:SystemRoot = $originalSystemRoot
    $env:TEMP = $originalTemp
}
