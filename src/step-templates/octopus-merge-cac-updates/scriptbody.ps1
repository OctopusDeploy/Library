# Check to see if $IsWindows is available
if ($null -eq $IsWindows)
{
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

Function Get-GitExecutable
{
    # Define parameters
    param (
        $WorkingDirectory
    )

    # Define variables
    $gitExe = "PortableGit-2.41.0.3-64-bit.7z.exe"
    $gitDownloadUrl = "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.3/$gitExe"
    $gitDownloadArguments = @{ }
    $gitDownloadArguments.Add("Uri", $gitDownloadUrl)
    $gitDownloadArguments.Add("OutFile", "$WorkingDirectory/git/$gitExe")

    # This makes downloading faster
    $ProgressPreference = 'SilentlyContinue'

    # Check to see if git subfolder exists
    if ((Test-Path -Path "$WorkingDirectory/git") -eq $false)
    {
        # Create subfolder
        New-Item -Path "$WorkingDirectory/git"  -ItemType Directory | Out-Null
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 6)
    {
        # Use basic parsing is required
        $gitDownloadArguments.Add("UseBasicParsing", $true)
    }

    # Download Git
    Write-Host "Downloading Git ..."
    Invoke-WebRequest @gitDownloadArguments

    # Extract Git
    $gitExtractArguments = @()
    $gitExtractArguments += "-o"
    $gitExtractArguments += "$WorkingDirectory\git"
    $gitExtractArguments += "-y"
    $gitExtractArguments += "-bd"

    Write-Host "Extracting Git download ..."
    & "$WorkingDirectory\git\$gitExe" $gitExtractArguments

    # Wait until unzip action is complete
    while ($null -ne (Get-Process | Where-Object { $_.ProcessName -eq ($gitExe.Substring(0,$gitExe.LastIndexOf("."))) }))
    {
        Start-Sleep 5
    }

    # Add bin folder to path
    $env:PATH = "$WorkingDirectory\git\bin$( [IO.Path]::PathSeparator )" + $env:PATH

    # Disable promopt for credential helper
    Invoke-CustomCommand "git" @("config", "--system", "--unset", "credential.helper") | Write-Results
}

Function Invoke-CustomCommand
{
    Param (
        $commandPath,
        $commandArguments,
        $workingDir = (Get-Location),
        $path = @(),
        $envVars = @{ }
    )

    $path += $env:PATH
    $newPath = $path -join [IO.Path]::PathSeparator

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.WorkingDirectory = $workingDir
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $pinfo.EnvironmentVariables["PATH"] = $newPath

    foreach ($env in $envVars.Keys)
    {
        Write-Verbose "Setting $env to $( $envVars.$env )"
        $pinfo.EnvironmentVariables.Add($env,$envVars.$env.ToString())
    }

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null

    # Capture output during process execution so we don't hang
    # if there is too much output.
    # Microsoft documents a C# solution here:
    # https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.redirectstandardoutput?view=net-7.0&redirectedfrom=MSDN#remarks
    # This code is based on https://stackoverflow.com/a/74748844
    $stdOut = [System.Text.StringBuilder]::new()
    $stdErr = [System.Text.StringBuilder]::new()
    do
    {
        if (!$p.StandardOutput.EndOfStream)
        {
            $stdOut.AppendLine($p.StandardOutput.ReadLine())
        }
        if (!$p.StandardError.EndOfStream)
        {
            $stdErr.AppendLine($p.StandardError.ReadLine())
        }

        Start-Sleep -Milliseconds 10
    }
    while (-not $p.HasExited)

    # Capture any standard output generated between our last poll and process end.
    while (!$p.StandardOutput.EndOfStream)
    {
        $stdOut.AppendLine($p.StandardOutput.ReadLine())
    }

    # Capture any error output generated between our last poll and process end.
    while (!$p.StandardError.EndOfStream)
    {
        $stdErr.AppendLine($p.StandardError.ReadLine())
    }

    $p.WaitForExit()

    $executionResults = [pscustomobject]@{
        StdOut = $stdOut.ToString()
        StdErr = $stdErr.ToString()
        ExitCode = $p.ExitCode
    }

    return $executionResults

}

function Write-Results
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $True, ValuefromPipeline = $True)]
        $results
    )

    if (![String]::IsNullOrWhiteSpace($results.StdOut))
    {
        Write-Verbose $results.StdOut
    }

    if (![String]::IsNullOrWhiteSpace($results.StdErr))
    {
        Write-Verbose $results.StdErr
    }
}

function Format-StringAsNullOrTrimmed {
    [cmdletbinding()]
    param (
        [Parameter(ValuefromPipeline=$True)]
        $input
    )

    if ([string]::IsNullOrWhitespace($input)) {
        return $null
    }

    return $input.Trim()
}

function Write-TerraformBackend
{
    Set-Content -Path 'backend.tf' -Value @"
terraform {
        backend "s3" {}
        required_providers {
          octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = ">= 0.21.1" }
        }
    }
"@
}

function Set-GitContactDetails
{
    $gitEmail = Invoke-CustomCommand "git" @("config", "--global", "user.email", "octopus@octopus.com")
    Write-Results $gitEmail
    if (-not $gitEmail.ExitCode -eq 0)
    {
        Write-Error "Failed to set the git email address (exit code was $( $gitEmail.ExitCode ))."
    }

    $gitUser = Invoke-CustomCommand "git" @("config", "--global", "user.name", "Octopus Server")
    Write-Results $gitUser
    if (-not $gitUser.ExitCode -eq 0)
    {
        Write-Error "Failed to set the git name (exit code was $( $gitUser.ExitCode ))."
    }
}

$spaceFilter = if (-not [string]::IsNullOrWhitespace($OctopusParameters["FindConflicts.Octopus.Spaces"]))
{
    $OctopusParameters["FindConflicts.Octopus.Spaces"].Split("`n")
}
else
{
    @()
}
$projectFilter = if (-not [string]::IsNullOrWhitespace($OctopusParameters["FindConflicts.Octopus.Projects"]))
{
    $OctopusParameters["FindConflicts.Octopus.Projects"].Split("`n")
}
else
{
    @()
}
$username = $OctopusParameters["FindConflicts.Git.Credentials.Username"]
$password = $OctopusParameters["FindConflicts.Git.Credentials.Password"]
$protocol = $OctopusParameters["FindConflicts.Git.Url.Protocol"]
$gitHost = $OctopusParameters["FindConflicts.Git.Url.Host"]
$org = $OctopusParameters["FindConflicts.Git.Url.Organization"]
$repo = $OctopusParameters["FindConflicts.Git.Url.Template"]
$region = $OctopusParameters["FindConflicts.Terraform.Backend.S3Region"]
$key = $OctopusParameters["FindConflicts.Terraform.Backend.S3Key"]
$bucket = $OctopusParameters["FindConflicts.Terraform.Backend.S3Bucket"]

if ([string]::IsNullOrWhitespace($username))
{
    Write-Error "The FindConflicts.Git.Credentials.Username variable must be provided"
}

if ([string]::IsNullOrWhitespace($password))
{
    Write-Error "The FindConflicts.Git.Credentials.Password variable must be provided"
}

if ( [string]::IsNullOrWhitespace($protocol))
{
    Write-Error "The FindConflicts.Git.Url.Protocol variable must be defined."
}

if ( [string]::IsNullOrWhitespace($gitHost))
{
    Write-Error "The FindConflicts.Git.Url.Host variable must be defined."
}

if ( [string]::IsNullOrWhitespace($repo))
{
    Write-Error "The FindConflicts.Git.Url.Template variable must be defined."
}

if ( [string]::IsNullOrWhitespace($region))
{
    Write-Error "The FindConflicts.Terraform.Backend.S3Region variable must be defined."
}

if ( [string]::IsNullOrWhitespace($key))
{
    Write-Error "The FindConflicts.Terraform.Backend.S3Key variable must be defined."
}

if ( [string]::IsNullOrWhitespace($bucket))
{
    Write-Error "The FindConflicts.Terraform.Backend.S3Bucket variable must be defined."
}

$templateRepoUrl = $protocol + "://" + $gitHost + "/" + $org + "/" + $repo + ".git"
$templateRepo = $protocol + "://" + $username + ":" + $password + "@" + $gitHost + "/" + $org + "/" + $repo + ".git"
$branch = "main"

# Check to see if it's Windows
if ($IsWindows -and $OctopusParameters['Octopus.Workerpool.Name'] -eq "Hosted Windows")
{
    # Dynamic worker don't have git, download portable version and add to path for execution
    Write-Host "Detected usage of Windows Dynamic Worker ..."
    Get-GitExecutable -WorkingDirectory $PWD
}

Write-TerraformBackend
Set-GitContactDetails

Invoke-CustomCommand "terraform" @("init", "-no-color", "-backend-config=`"bucket=$bucket`"", "-backend-config=`"region=$region`"", "-backend-config=`"key=$key`"") | Write-Results

Write-Host "Verbose logs contain instructions for resolving merge conflicts."

$workspaces = Invoke-CustomCommand "terraform" @("workspace", "list")

Write-Results $workspaces

$parsedWorkspaces = $workspaces.StdOut.Replace("*", "").Split("`n")

foreach ($workspace in $parsedWorkspaces)
{
    $trimmedWorkspace = $workspace | Format-StringAsNullOrTrimmed

    if ($trimmedWorkspace -eq "default" -or [string]::IsNullOrWhitespace($trimmedWorkspace))
    {
        continue
    }

    Write-Verbose "Processing workspace $trimmedWorkspace"

    Invoke-CustomCommand "terraform" @("workspace", "select", $trimmedWorkspace) | Write-Results

    $state = Invoke-CustomCommand "terraform" @("show", "-json")

    # state might include sensitive values, so don't print it unless there was an error

    if (-not $state.ExitCode -eq 0)
    {
        Write-Results $state
        continue
    }

    $parsedState = $state.StdOut | ConvertFrom-Json

    $resources = $parsedState.values.root_module.resources | Where-Object {
        $_.type -eq "octopusdeploy_project"
    }

    # The outputs allow us to contact the downstream instance)
    $spaceName = (Invoke-CustomCommand "terraform" @("output", "-raw", "octopus_space_name")).StdOut | Format-StringAsNullOrTrimmed

    foreach ($resource in $resources)
    {
        $url = $resource.values.git_library_persistence_settings.url | Format-StringAsNullOrTrimmed
        $name = $resource.values.name | Format-StringAsNullOrTrimmed

        # Optional filtering
        if (-not($spaceFilter.Count -eq 0 -or $spaceFilter.Contains($spaceName)))
        {
            continue
        }

        if (-not($projectFilter.Count -eq 0 -or $projectFilter.Contains($name)))
        {
            continue
        }

        if (-not [string]::IsNullOrWhitespace($url))
        {
            mkdir $trimmedWorkspace | Out-Null

            $parsedUrl = [System.Uri]$url
            $urlWithCreds = $parsedUrl.Scheme + "://" + $username + ":" + $password + "@" + $parsedUrl.Host + ":" + $parsedUrl.Port + $parsedUrl.AbsolutePath

            Write-Verbose "Cloning repo"
            $cloneRepo = Invoke-CustomCommand "git" @("clone", $urlWithCreds, $trimmedWorkspace)
            Write-Results $cloneRepo
            if (-not $cloneRepo.ExitCode -eq 0)
            {
                Write-Error "Failed to clone repo (exit code was $( $cloneRepo.ExitCode ))."
            }

            Write-Verbose "Cloning upstream remote"
            $addRemote = Invoke-CustomCommand "git" @("remote", 'add', 'upstream', $templateRepo) $trimmedWorkspace
            Write-Results $addRemote
            if (-not $addRemote.ExitCode -eq 0)
            {
                Write-Error "Failed to clone repo (exit code was $( $addRemote.ExitCode ))."
            }

            Write-Verbose "Fetching all"
            $fetchAll = Invoke-CustomCommand "git" @("fetch", "--all") $trimmedWorkspace
            Write-Results $fetchAll
            if (-not $fetchAll.ExitCode -eq 0)
            {
                Write-Error "Failed to fetch all (exit code was $( $fetchAll.ExitCode ))."
            }

            Write-Verbose "Checking out upstream-$branch upstream/$branch"
            $checkoutUpstream = Invoke-CustomCommand "git" @("checkout", "-b", "upstream-$branch", "upstream/$branch") $trimmedWorkspace
            Write-Results $checkoutUpstream
            if (-not $checkoutUpstream.ExitCode -eq 0)
            {
                Write-Error "Failed to checkout upstream (exit code was $( $checkoutUpstream.ExitCode ))."
            }

            if (-not($branch -eq "master" -or $branch -eq "main"))
            {
                Write-Verbose "Checking out $branch origin/$branch"
                $checkoutDownstream = Invoke-CustomCommand "git" @("checkout", "-b", $branch, "origin/$branch") $trimmedWorkspace
            }
            else
            {
                Write-Verbose "Checking out $branch"
                $checkoutDownstream = Invoke-CustomCommand "git" @("checkout", $branch) $trimmedWorkspace
            }

            Write-Results $checkoutDownstream
            if (-not $checkoutDownstream.ExitCode -eq 0)
            {
                Write-Error "Failed to checkout downstream (exit code was $( $checkoutDownstream.ExitCode ))."
            }

            Write-Verbose "Merge base"
            $mergeBase = Invoke-CustomCommand "git" @("merge-base", $branch, "upstream-$branch") $trimmedWorkspace
            Write-Results $mergeBase
            if (-not $mergeBase.ExitCode -eq 0)
            {
                Write-Error "Failed to merge base (exit code was $( $mergeBase.ExitCode ))."
            }

            Write-Verbose "Rev parse"
            $mergeSourceCurrentCommit = Invoke-CustomCommand "git" @("rev-parse", "upstream-$branch") $trimmedWorkspace
            Write-Results $mergeSourceCurrentCommit
            if (-not $mergeSourceCurrentCommit.ExitCode -eq 0)
            {
                Write-Error "Failed to rev parse (exit code was $( $mergeSourceCurrentCommit.ExitCode ))."
            }

            Write-Verbose "Merge (no commit)"
            $mergeResult = Invoke-CustomCommand "git" @("merge", "--no-commit", "--no-ff", "upstream-$branch") $trimmedWorkspace
            Write-Results $mergeResult

            if ($mergeBase.StdOut -eq $mergeSourceCurrentCommit.StdOut)
            {
                Write-Host "No changes found in the upstream repo $templateRepoUrl that do not exist in the downstream repo $url for project `"$name`" in space $spaceName"
            }
            elseif (-not $mergeResult.ExitCode -eq 0)
            {
                Write-Warning "Changes between upstream repo $templateRepoUrl conflict with changes in downstream repo $url for project `"$name`" in space $spaceName."
                Write-Verbose "To resolve the conflicts, run the following commands:"
                Write-Verbose "mkdir cac"
                Write-Verbose "cd cac"
                Write-Verbose "git clone $url ."
                Write-Verbose "git remote add upstream $templateRepoUrl"
                Write-Verbose "git fetch --all"
                Write-Verbose "git checkout -b upstream-$branch upstream/$branch"
                if (-not($branch -eq "master" -or $branch -eq "main"))
                {
                    Write-Verbose "git checkout -b $branch origin/$branch"
                }
                else
                {
                    Write-Verbose "git checkout $branch"
                    Write-Verbose "git merge-base $branch upstream-$branch"
                    Write-Verbose "git merge --no-commit --no-ff upstream-$branch"
                }
            }
            else
            {
                # https://stackoverflow.com/a/76272919
                # How to commit a merge non-interactively
                Write-Verbose "Git commit"
                $mergeContinue = Invoke-CustomCommand "git" @("commit", "--no-edit") $trimmedWorkspace
                Write-Results $mergeContinue
                if (-not $mergeContinue.ExitCode -eq 0)
                {
                    Write-Error "Failed to merge continue (exit code was $( $mergeContinue.ExitCode ))."
                }

                $diffResult = Invoke-CustomCommand "git" @("diff", "--quiet", "--exit-code", "@{upstream}") $trimmedWorkspace
                Write-Results $diffResult

                if (-not $diffResult.ExitCode -eq 0)
                {
                    $pushResult = Invoke-CustomCommand "git" @("push", "origin") $trimmedWorkspace
                    Write-Results $pushResult

                    if ($pushResult.ExitCode -eq 0)
                    {
                        Write-Host "Changes were merged between upstream repo $templateRepoUrl and downstream repo $url for project `"$name`" in space $spaceName."
                    }
                    else
                    {
                        Write-Warning "Failed to push changes to downstream repo $url for project `"$name`" in space $spaceName (exit code $( $pushResult.ExitCode ))."
                    }
                }
                else
                {
                    Write-Host "No changes found in the upstream repo $templateRepoUrl that do not exist in the downstream repo $url for project `"$name`" in space $spaceName"
                }
            }
        }
        else
        {
            Write-Verbose "`"$name`" is not a CaC project"
        }
    }
}