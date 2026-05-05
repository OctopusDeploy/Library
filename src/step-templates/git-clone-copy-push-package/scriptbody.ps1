Function Invoke-Git
{
	# Define parameters
    param (
    	$GitRepositoryUrl,
        $GitFolder,
        $GitUsername,
        $GitPassword,
        $GitCommand,
        $AdditionalArguments
    )
    
    # Get current work folder
    $workDirectory = Get-Location

	# Check to see if GitFolder exists
    if (![String]::IsNullOrWhitespace($GitFolder) -and (Test-Path -Path $GitFolder) -eq $false)
    {
    	# Create the folder
        New-Item -Path $GitFolder -ItemType "Directory" -Force | Out-Null
        
        # Set the location to the new folder
        Set-Location -Path $GitFolder
    }
    
    # Create arguments array
    $gitArguments = @()
    $gitArguments += $GitCommand
    
    # Check for url
    if (![string]::IsNullOrWhitespace($GitRepositoryUrl))
    {
      # Convert url to URI object
      $gitUri = [System.Uri]$GitRepositoryUrl
      $gitUrl = "{0}://{1}:{2}@{3}:{4}{5}" -f $gitUri.Scheme, $GitUsername, $GitPassword, $gitUri.Host, $gitUri.Port, $gitUri.PathAndQuery
      $gitArguments += $gitUrl

      # Get the newly created folder name
      $gitFolderName = $GitRepositoryUrl.SubString($GitRepositoryUrl.LastIndexOf("/") + 1)
      if ($gitFolderName.Contains(".git"))
      {
          $gitFolderName = $gitFolderName.SubString(0, $gitFolderName.IndexOf("."))
      }
    }
   
    
    # Check for additional arguments
    if ($null -ne $AdditionalArguments)
    {
 		# Add the additional arguments
        $gitArguments += $AdditionalArguments
    }
    
    # Execute git command
    $results = Execute-Command -commandPath "git" -commandArguments $gitArguments -workingDir $GitFolder
    
    Write-Host $results.stdout
    Write-Host $results.stderr
    
    # Return the foldername
    Set-Location -Path $workDirectory
    
    # Check to see if GitFolder is null
    if ($null -ne $GitFolder)
    {
    	return Join-Path -Path $GitFolder -ChildPath $gitFolderName
    }
}

# Check to see if $IsWindows is available
if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

Function Copy-Files
{
	# Define parameters
    param (
    	$SourcePath,
        $DestinationPath
    )
    
    # Copy the items from source path to destination path
    $copyArguments = @{}
    $copyArguments.Add("Path", $SourcePath)
    $copyArguments.Add("Destination", $DestinationPath)
    
    # Check to make sure destination exists
    if ((Test-Path -Path $DestinationPath) -eq $false)
    {
    	# Create the destination path
        New-Item -Path $DestinationPath -ItemType "Directory" | Out-Null
    }
    
    # Check for wildcard
    if ($SourcePath.EndsWith("/*") -or $SourcePath.EndsWith("\*"))
    {
		# Add recurse argument
		$copyArguments.Add("Recurse", $true)
    }
    
    $copyArguments.Add("Force", $true)
    
    # Copy files
    Copy-Item @copyArguments
}

Function Execute-Command
{
	param (
    	$commandPath,
        $commandArguments,
        $workingDir
    )

	$gitExitCode = 0
    $executionResults = $null

  Try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.WorkingDirectory = $workingDir
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $executionResults = [pscustomobject]@{
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $null
    }
    $p.WaitForExit()
    $gitExitCode = [int]$p.ExitCode
    $executionResults.ExitCode = $gitExitCode
    
    if ($gitExitCode -ge 2) 
    {
		# Fail the step
        throw
    }
    
    return $executionResults
  }
  Catch {
    # Check exit code
    Write-Error -Message "$($executionResults.stderr)" -ErrorId $gitExitCode
    exit $gitExitCode
  }

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
    $gitDownloadArguments = @{}
    $gitDownloadArguments.Add("Uri", $gitDownloadUrl)
    $gitDownloadArguments.Add("OutFile", "$WorkingDirectory/git/$gitExe")
    
    # This makes downloading faster
    $ProgressPreference = 'SilentlyContinue'
    
    # Check to see if git subfolder exists
    if ((Test-Path -Path "$WorkingDirectory/git") -eq $false)
    {
    	# Create subfolder
        New-Item -Path "$WorkingDirectory/git"  -ItemType Directory
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
    while ($null -ne (Get-Process | Where-Object {$_.ProcessName -eq ($gitExe.Substring(0, $gitExe.LastIndexOf(".")))}))
    {
        Start-Sleep 5
    }
    
    # Add bin folder to path
    $env:PATH = "$WorkingDirectory\git\bin$([IO.Path]::PathSeparator)" + $env:PATH
    
    # Disable promopt for credential helper
    Invoke-Git -GitCommand "config" -AdditionalArguments @("--system", "--unset", "credential.helper")
}

# Get variables
$gitUrl = $OctopusParameters['Template.Git.Repo.Url']
$gitUser = $OctopusParameters['Template.Git.User.Name']
$gitPassword = $OctopusParameters['Template.Git.User.Password']
$sourceItems = $OctopusParameters['Octopus.Action.Package[Template.Package.Reference].ExtractedPath']
$destinationPath = $OctopusParameters['Template.Git.Destination.Path']
$gitSource = $null
$gitDestination = $null

# Check to see if it's Windows
if ($IsWindows -and $OctopusParameters['Octopus.Workerpool.Name'] -eq "Hosted Windows")
{
	# Dynamic worker don't have git, download portable version and add to path for execution
    Write-Host "Detected usage of Windows Dynamic Worker ..."
    Get-GitExecutable -WorkingDirectory $PWD
}

# Clone repository
$folderName = Invoke-Git -GitRepositoryUrl $gitUrl -GitUsername $gitUser -GitPassword $gitPassword -GitCommand "clone" -GitFolder "$($PWD)/default"

$gitSource = $sourceItems
$gitDestination = $folderName

# Copy files from source to destination
Copy-Files -SourcePath "$($gitSource)/*" -DestinationPath "$($gitDestination)$($destinationPath)"

# Set user
$gitAuthorName = $OctopusParameters['Octopus.Deployment.CreatedBy.DisplayName']
$gitAuthorEmail = $OctopusParameters['Octopus.Deployment.CreatedBy.EmailAddress']

# Check to see if user is system
if ([string]::IsNullOrWhitespace($gitAuthorEmail) -and $gitAuthorName -eq "System")
{
	# Initiated by the Octopus server via automated process, put something in for the email address
    $gitAuthorEmail = "system@octopus.local"
}

Invoke-Git -GitCommand "config" -AdditionalArguments @("user.name", $gitAuthorName) -GitFolder "$($folderName)" | Out-Null
Invoke-Git -GitCommand "config" -AdditionalArguments @("user.email", $gitAuthorEmail) -GitFolder "$($folderName)" | Out-Null

# Commit changes
Invoke-Git -GitCommand "add" -GitFolder "$folderName" -AdditionalArguments @(".") | Out-Null
Invoke-Git -GitCommand "commit" -GitFolder "$folderName" -AdditionalArguments @("-m", "`"Commit from #{Octopus.Project.Name} release version #{Octopus.Release.Number}`"") | Out-Null

# Push the changes back to git
Invoke-Git -GitCommand "push" -GitFolder "$folderName" | Out-Null

