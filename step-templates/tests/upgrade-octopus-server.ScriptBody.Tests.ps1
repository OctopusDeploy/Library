$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$scriptPath = Join-Path $PSScriptRoot ".." "upgrade-octopus-server.ScriptBody.ps1"
$scriptBody = [System.IO.File]::ReadAllText($scriptPath)
$scriptBodyWithoutEntryPoint = $scriptBody -replace '(?m)^StartInstallationOfOctopusServer\s*$', ''
. ([scriptblock]::Create($scriptBodyWithoutEntryPoint))

function New-FakeWebClient {
    param(
        [scriptblock] $DownloadFile
    )

    $webClient = [pscustomobject]@{}
    Add-Member -InputObject $webClient -MemberType ScriptMethod -Name DownloadFile -Value $DownloadFile
    return $webClient
}

function msiexec {}

Describe "Upgrade Octopus Server download safety" {
    BeforeEach {
        $script:DownloadedFile = $null
    }

    AfterEach {
        if ($script:DownloadedFile -and (Test-Path -LiteralPath $script:DownloadedFile)) {
            Remove-Item -LiteralPath $script:DownloadedFile -Force
        }
    }

    It "removes the partial file and terminates when the download fails" {
        Mock New-Object {
            New-FakeWebClient -DownloadFile {
                param($Url, $Path)
                $script:DownloadedFile = $Path
                throw "download failed"
            }
        } -ParameterFilter { $TypeName -eq "System.Net.WebClient" }

        { DownloadOctopusServer "2026.3.15878" } | Should Throw "download failed"
        Test-Path -LiteralPath $script:DownloadedFile | Should Be $false
    }

    It "terminates when the downloaded file is empty" {
        Mock New-Object {
            New-FakeWebClient -DownloadFile {
                param($Url, $Path)
                $script:DownloadedFile = $Path
            }
        } -ParameterFilter { $TypeName -eq "System.Net.WebClient" }

        { DownloadOctopusServer "2026.3.15878" } | Should Throw "empty"
        Test-Path -LiteralPath $script:DownloadedFile | Should Be $false
    }

    It "returns exactly one path and reports completion after a valid download" {
        Mock New-Object {
            New-FakeWebClient -DownloadFile {
                param($Url, $Path)
                $script:DownloadedFile = $Path
                [System.IO.File]::WriteAllBytes($Path, [byte[]](1, 2, 3))
            }
        } -ParameterFilter { $TypeName -eq "System.Net.WebClient" }
        Mock Write-Host {}

        $result = @(DownloadOctopusServer "2026.3.15878")

        $result.Count | Should Be 1
        $result[0] | Should Be $script:DownloadedFile
        $result[0].GetType().FullName | Should Be "System.String"
        Assert-MockCalled Write-Host -Times 1 -ParameterFilter {
            $Object -eq "Download completed"
        }
    }

    It "does not stop or install when the download terminates" {
        Mock DownloadOctopusServer { throw "download failed" }
        Mock StopOctopusServer {}
        Mock InstallOctopusServer {}
        Mock StartOctopusServer {}

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15878" } | Should Throw "download failed"

        Assert-MockCalled StopOctopusServer -Times 0
        Assert-MockCalled InstallOctopusServer -Times 0
        Assert-MockCalled StartOctopusServer -Times 0
    }
}

Describe "Upgrade Octopus Server installation safety" {
    It "waits for msiexec with one quoted MSI path" {
        Mock msiexec {}
        Mock Start-Process {
            [pscustomobject]@{ ExitCode = 0 }
        }

        InstallOctopusServer "C:\Temp\Octopus Server.msi"

        Assert-MockCalled msiexec -Times 0
        Assert-MockCalled Start-Process -Times 1 -ParameterFilter {
            $expectedArguments = @("/i", '"C:\Temp\Octopus Server.msi"', "/quiet", "/norestart")
            $argumentDifference = Compare-Object $ArgumentList $expectedArguments -SyncWindow 0
            ($FilePath -eq "msiexec.exe") -and $Wait -and $PassThru -and ($null -eq $argumentDifference)
        }
    }

    It "terminates with the msiexec exit code when installation fails" {
        Mock msiexec {}
        Mock Start-Process {
            [pscustomobject]@{ ExitCode = 1603 }
        }

        { InstallOctopusServer "C:\Temp\Octopus.msi" } | Should Throw "1603"
    }

    It "stops, installs, starts, and cleans up in order on success" {
        $script:Operations = @()
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer { $script:Operations += "stop" }
        Mock InstallOctopusServer { $script:Operations += "install" }
        Mock StartOctopusServer { $script:Operations += "start" }
        Mock RemoveTempFile { $script:Operations += "cleanup" }

        InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15878"

        $script:Operations -join "," | Should Be "stop,install,start,cleanup"
    }

    It "starts the server and cleans up when installation fails" {
        $script:Operations = @()
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer { $script:Operations += "stop" }
        Mock InstallOctopusServer {
            $script:Operations += "install"
            throw "installation failed"
        }
        Mock StartOctopusServer { $script:Operations += "start" }
        Mock RemoveTempFile { $script:Operations += "cleanup" }

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15878" } | Should Throw "installation failed"

        $script:Operations -join "," | Should Be "stop,install,start,cleanup"
    }

    It "cleans up without installing or starting when server stop fails" {
        $script:Operations = @()
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer {
            $script:Operations += "stop"
            throw "stop failed"
        }
        Mock InstallOctopusServer { $script:Operations += "install" }
        Mock StartOctopusServer { $script:Operations += "start" }
        Mock RemoveTempFile { $script:Operations += "cleanup" }

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15878" } | Should Throw "stop failed"

        $script:Operations -join "," | Should Be "stop,cleanup"
    }

    It "preserves the installation failure and reports a recovery failure" {
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer {}
        Mock InstallOctopusServer { throw "installation failed" }
        Mock StartOctopusServer { throw "recovery failed" }
        Mock RemoveTempFile {}
        Mock Write-Warning {}

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15878" } | Should Throw "installation failed"

        Assert-MockCalled Write-Warning -Times 1 -ParameterFilter {
            $Message -like "*recovery failed*"
        }
        Assert-MockCalled RemoveTempFile -Times 1
    }
}
