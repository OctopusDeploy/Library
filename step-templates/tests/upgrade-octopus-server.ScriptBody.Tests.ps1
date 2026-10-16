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
