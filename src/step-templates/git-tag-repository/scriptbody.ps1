Function Invoke-Git
{
	# Define parameters
    param (
    	$GitRepositoryUrl,
        $GitFolder,
        $GitUsername,
        $GitPassword,
        $GitCommand,
        $AdditionalArguments,
        $SupressOutput = $false
    )
    
    # Get current work folder
    $workDirectory = Get-Location
    
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
    $results = Execute-Command "git" $gitArguments $GitFolder
    
    # Check to see if output is supposed to be suppressed
    if ($SupressOutput -ne $true)
    {
    	Write-Host $results.stdout
    }

	# Always display error messages
    Write-Host $results.stderr
    
    # Store results into file
    Add-Content -Path "$PWD/$($GitCommand).txt" -Value $results.stdout
    
    # Return the foldername
   	return $gitFolderName
}

# Check to see if $IsWindows is available
if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
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


# Get variables
$gitUrl = $OctopusParameters['Template.Git.Repo.Url']
$gitUser = $OctopusParameters['Template.Git.User.Name']
$gitPassword = $OctopusParameters['Template.Git.User.Password']
$gitTag = $OctopusParameters['Template.Git.Tag']
$gitAction = $OctopusParameters['Template.Git.Action']

# Clone repository
$folderName = Invoke-Git -GitRepositoryUrl $gitUrl -GitUsername $gitUser -GitPassword $gitPassword -GitCommand "clone"

# Set user
$gitAuthorName = $OctopusParameters['Octopus.Deployment.CreatedBy.DisplayName']
$gitAuthorEmail = $OctopusParameters['Octopus.Deployment.CreatedBy.EmailAddress']

# Check to see if user is system
if ([string]::IsNullOrWhitespace($gitAuthorEmail) -and $gitAuthorName -eq "System")
{
	# Initiated by the Octopus server via automated process, put something in for the email address
    $gitAuthorEmail = "system@octopus.local"
}

# Configure user information
Invoke-Git -GitCommand "config" -AdditionalArguments @("user.name", $gitAuthorName) -GitFolder "$($PWD)/$($folderName)"
Invoke-Git -GitCommand "config" -AdditionalArguments @("user.email", $gitAuthorEmail) -GitFolder "$($PWD)/$($folderName)"

# Record existing tags, if any
Invoke-Git -GitCommand "tag" -GitFolder "$($PWD)/$($folderName)" -SupressOutput $true

# Check the file
$existingTags = Get-Content "$PWD/tag.txt"

if (![String]::IsNullOrWhitespace($existingTags))
{
	# Parse
    $existingTags = $existingTags.Split("`n",[System.StringSplitOptions]::RemoveEmptyEntries)
    
    # Check to see if tag already exists
    if ($null -ne ($existingTags | Where-Object {$_ -eq $gitTag}))
    {
		# Check the selected action
        switch ($gitAction)
        {
        	"delete"
            {
                # Delete the tag locally
                Write-Host "Deleting tag $gitTag from cloned repository ..."
                Invoke-Git -GitCommand "tag" -AdditionalArguments @("--delete", "$gitTag") -GitFolder "$($PWD)/$($folderName)"
                
                # Delete the tag on remote
                Write-Host "Deleting tag from remote repository ..."
                Invoke-Git -GitCommand "push" -AdditionalArguments @(":refs/tags/$gitTag") -GitFolder "$($PWD)/$($folderName)" -GitRepositoryUrl $gitUrl -GitUsername $gitUser -GitPassword $gitPassword
                
                break
            }
            "ignore"
            {
            	# Ignore and continue
                Write-Host "$gitTag already exists on $gitUrl.  Selected action is Ignore, exiting."
                
                exit 0
            }
            "fail"
            {
				# Error, tag already exists
        		Write-Error "Error: $gitTag already exists on $gitUrl!"
            }
        }
    }
}

# Tag the repo
Invoke-Git -GitCommand "tag" -AdditionalArguments @("-a", $gitTag, "-m", "`"Tag from #{Octopus.Project.Name} release version #{Octopus.Release.Number}`"") -GitFolder "$($PWD)/$($folderName)"

# Push the new tag
Invoke-Git -Gitcommand "push" -AdditionalArguments @("--tags") -GitFolder "$($PWD)/$($folderName)"