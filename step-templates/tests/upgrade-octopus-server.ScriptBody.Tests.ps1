$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$scriptPath = [System.IO.Path]::Combine($PSScriptRoot, "..", "upgrade-octopus-server.ScriptBody.ps1")
$scriptBody = [System.IO.File]::ReadAllText($scriptPath)
$scriptBodyWithoutEntryPoint = $scriptBody -replace '(?m)^StartInstallationOfOctopusServer\s*$', ''

# These stubs make the revised internal seams mockable while the tests are red against master.
function NewOctopusTempFile { [System.IO.Path]::GetTempFileName() }
function InvokeOctopusDownloadRequest { throw "The ranged downloader is not implemented." }

. ([scriptblock]::Create($scriptBodyWithoutEntryPoint))

function New-FakeDownloadResponse {
    param(
        [System.Net.HttpStatusCode] $StatusCode,
        [long] $ContentLength,
        [string] $ContentRange,
        [byte[]] $Content = @()
    )

    $response = [pscustomobject]@{
        StatusCode = $StatusCode
        ContentLength = $ContentLength
        Headers = @{ "Content-Range" = $ContentRange }
        Stream = New-Object System.IO.MemoryStream -ArgumentList @(,$Content)
    }
    Add-Member -InputObject $response -MemberType ScriptMethod -Name GetResponseStream -Value { $this.Stream }
    Add-Member -InputObject $response -MemberType ScriptMethod -Name Dispose -Value { $this.Stream.Dispose() }
    return $response
}

function msiexec {}

Describe "Upgrade Octopus Server ranged download" {
    BeforeEach {
        $script:DownloadedFile = $null
        $script:Requests = @()

        Mock NewOctopusTempFile {
            $script:DownloadedFile = [System.IO.Path]::GetTempFileName()
            return $script:DownloadedFile
        }
        Mock New-Object { throw "The legacy WebClient downloader was invoked." } `
            -ParameterFilter { $TypeName -eq "System.Net.WebClient" }
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = "Valid" } }
        Mock Write-Host {}
        Mock Start-Sleep {}
    }

    AfterEach {
        if ($script:DownloadedFile -and (Test-Path -LiteralPath $script:DownloadedFile)) {
            Remove-Item -LiteralPath $script:DownloadedFile -Force
        }
    }

    It "downloads consecutive ranges and returns one validated path" {
        Mock InvokeOctopusDownloadRequest {
            $script:Requests += "$Method`:$RangeStart-$RangeEnd"
            if ($Method -eq "HEAD") {
                return New-FakeDownloadResponse -StatusCode OK -ContentLength 7
            }

            $length = [int]($RangeEnd - $RangeStart + 1)
            return New-FakeDownloadResponse -StatusCode PartialContent `
                -ContentLength $length `
                -ContentRange "bytes $RangeStart-$RangeEnd/7" `
                -Content ([byte[]](1..$length))
        }

        $result = @(DownloadOctopusServer "2026.3.15954" 3 3)

        $result.Count | Should Be 1
        $result[0] | Should Be $script:DownloadedFile
        (Get-Item -LiteralPath $result[0]).Length | Should Be 7
        $script:Requests -join "," | Should Be "HEAD:-,GET:0-2,GET:3-5,GET:6-6"
        Assert-MockCalled Get-AuthenticodeSignature -Times 1
        Assert-MockCalled Write-Host -Times 1 -ParameterFilter { $Object -eq "Download completed" }
    }

    It "retries a failed range from the last completed byte" {
        $script:RangeAttempts = 0
        Mock InvokeOctopusDownloadRequest {
            if ($Method -eq "HEAD") {
                return New-FakeDownloadResponse -StatusCode OK -ContentLength 4
            }

            $script:RangeAttempts++
            $script:Requests += "$RangeStart-$RangeEnd"
            if ($script:RangeAttempts -eq 1) { throw "connection reset" }
            return New-FakeDownloadResponse -StatusCode PartialContent `
                -ContentLength 4 -ContentRange "bytes 0-3/4" -Content ([byte[]](1, 2, 3, 4))
        }
        Mock Write-Warning {}

        $result = DownloadOctopusServer "2026.3.15954" 4 3

        $result | Should Be $script:DownloadedFile
        $script:Requests -join "," | Should Be "0-3,0-3"
        Assert-MockCalled Write-Warning -Times 1
    }

    It "removes the partial file after exhausting the retry limit" {
        Mock InvokeOctopusDownloadRequest {
            if ($Method -eq "HEAD") {
                return New-FakeDownloadResponse -StatusCode OK -ContentLength 4
            }
            throw "connection reset"
        }

        { DownloadOctopusServer "2026.3.15954" 4 3 } | Should Throw "connection reset"
        Test-Path -LiteralPath $script:DownloadedFile | Should Be $false
        Assert-MockCalled InvokeOctopusDownloadRequest -Times 3 -ParameterFilter { $Method -eq "GET" }
    }

    It "rejects an invalid range response and removes the file" {
        Mock InvokeOctopusDownloadRequest {
            if ($Method -eq "HEAD") {
                return New-FakeDownloadResponse -StatusCode OK -ContentLength 3
            }
            return New-FakeDownloadResponse -StatusCode OK -ContentLength 3 `
                -ContentRange $null -Content ([byte[]](1, 2, 3))
        }

        { DownloadOctopusServer "2026.3.15954" 3 1 } | Should Throw "invalid response"
        Test-Path -LiteralPath $script:DownloadedFile | Should Be $false
    }

    It "rejects a range with an unexpected byte count" {
        Mock InvokeOctopusDownloadRequest {
            if ($Method -eq "HEAD") {
                return New-FakeDownloadResponse -StatusCode OK -ContentLength 3
            }
            return New-FakeDownloadResponse -StatusCode PartialContent -ContentLength 2 `
                -ContentRange "bytes 0-2/3" -Content ([byte[]](1, 2))
        }

        { DownloadOctopusServer "2026.3.15954" 3 1 } | Should Throw "unexpected file length"
        Test-Path -LiteralPath $script:DownloadedFile | Should Be $false
    }

    It "rejects an installer without a valid Authenticode signature" {
        Mock InvokeOctopusDownloadRequest {
            if ($Method -eq "HEAD") {
                return New-FakeDownloadResponse -StatusCode OK -ContentLength 3
            }
            return New-FakeDownloadResponse -StatusCode PartialContent -ContentLength 3 `
                -ContentRange "bytes 0-2/3" -Content ([byte[]](1, 2, 3))
        }
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = "NotSigned" } }

        { DownloadOctopusServer "2026.3.15954" 3 1 } | Should Throw "Authenticode"
        Test-Path -LiteralPath $script:DownloadedFile | Should Be $false
    }

    It "does not stop or install when the download terminates" {
        Mock DownloadOctopusServer { throw "download failed" }
        Mock StopOctopusServer {}
        Mock InstallOctopusServer {}
        Mock StartOctopusServer {}

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15954" } | Should Throw "download failed"

        Assert-MockCalled StopOctopusServer -Times 0
        Assert-MockCalled InstallOctopusServer -Times 0
        Assert-MockCalled StartOctopusServer -Times 0
    }
}

Describe "Upgrade Octopus Server installation safety" {
    It "waits for msiexec with one quoted MSI path" {
        Mock msiexec {}
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

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
        Mock Start-Process { [pscustomobject]@{ ExitCode = 1603 } }

        { InstallOctopusServer "C:\Temp\Octopus.msi" } | Should Throw "1603"
    }

    It "stops, installs, starts, and cleans up in order on success" {
        $script:Operations = @()
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer { $script:Operations += "stop" }
        Mock InstallOctopusServer { $script:Operations += "install" }
        Mock StartOctopusServer { $script:Operations += "start" }
        Mock RemoveTempFile { $script:Operations += "cleanup" }

        InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15954"

        $script:Operations -join "," | Should Be "stop,install,start,cleanup"
    }

    It "starts the server and cleans up when installation fails" {
        $script:Operations = @()
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer { $script:Operations += "stop" }
        Mock InstallOctopusServer { $script:Operations += "install"; throw "installation failed" }
        Mock StartOctopusServer { $script:Operations += "start" }
        Mock RemoveTempFile { $script:Operations += "cleanup" }

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15954" } | Should Throw "installation failed"

        $script:Operations -join "," | Should Be "stop,install,start,cleanup"
    }

    It "cleans up without installing or starting when server stop fails" {
        $script:Operations = @()
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer { $script:Operations += "stop"; throw "stop failed" }
        Mock InstallOctopusServer { $script:Operations += "install" }
        Mock StartOctopusServer { $script:Operations += "start" }
        Mock RemoveTempFile { $script:Operations += "cleanup" }

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15954" } | Should Throw "stop failed"

        $script:Operations -join "," | Should Be "stop,cleanup"
    }

    It "preserves the installation failure and reports a recovery failure" {
        Mock DownloadOctopusServer { "C:\Temp\Octopus.msi" }
        Mock StopOctopusServer {}
        Mock InstallOctopusServer { throw "installation failed" }
        Mock StartOctopusServer { throw "recovery failed" }
        Mock RemoveTempFile {}
        Mock Write-Warning {}

        { InstallSetVersionOnOctopusServer "2025.4.10250" "2026.3.15954" } | Should Throw "installation failed"

        Assert-MockCalled Write-Warning -Times 1 -ParameterFilter { $Message -like "*recovery failed*" }
        Assert-MockCalled RemoveTempFile -Times 1
    }
}

Describe "Upgrade Octopus Server template contract" {
    BeforeAll {
        $templatePath = [System.IO.Path]::Combine($PSScriptRoot, "..", "upgrade-octopus-server.json")
        $template = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
    }

    It "preserves the template identity and parameters" {
        $template.Id | Should Be "4b3a1f09-1827-41bb-88a4-894c6317922b"
        @($template.Parameters.Name) -join "," | Should Be "InstanceName,InstallPath,SpecificOctopusServerVersionToInstall"
    }

    It "publishes version 11 with current modification metadata" {
        $template.Version | Should Be 11
        $template.'$Meta'.OctopusVersion | Should Be "2026.3.15954"
        $template.LastModifiedBy | Should Be "bcullman"
        $template.LastModifiedDate | Should Not BeNullOrEmpty
    }
}
