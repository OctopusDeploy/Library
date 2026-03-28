# Check to see if $IsWindows is available
if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Get variables
$gitUrl = $OctopusParameters['Template.Git.Repo.Url']
$gitUser = $OctopusParameters['Template.Git.User.Name']
$gitPassword = $OctopusParameters['Template.Git.User.Password']
$gitSourceBranch = $OctopusParameters['Template.Git.Source.Branch']
$gitDestinationBranch = $OctopusParameters['Template.Git.Destination.Branch']
$gitTech = $OctopusParameters['Template.Git.Repository.Technology']

# Convert url into uri object
$gitUri = [System.Uri]$gitUrl

switch ($gitTech)
{
    "ado"
    {

		# Parse url
        $gitOrganization = $gitUri.AbsolutePath
        $gitOrganization = $gitOrganization.Substring(1)
		$gitOrganization = $gitOrganization.Substring(0, $gitOrganization.IndexOf("/"))
        
        # Encode personal access token
        $encodedPAT = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("`:$gitPassword"))
        
        # Construct Headers
        $header = @{
        	Authorization = "Basic $encodedPAT"
        }
                
        $gitProject = $gitUri.AbsolutePath.Replace($gitOrganization, "").Replace("//", "")
        $gitProject = $gitProject.Substring(0, $gitProject.IndexOf("/"))
        
		# Create pull request
        $jsonBody = @{
        	sourceRefName = "refs/heads/" + $gitSourceBranch
            targetRefName = "refs/heads/" + $gitDestinationBranch
            title = "PR from Octopus Deploy"
            description = "PR from #{Octopus.Project.Name} release version #{Octopus.Release.Number}"
        }
        
        # Construct API call
        $adoApiUrl = "{0}://{1}:{2}/{3}/{4}/_apis/git/repositories/{4}/pullrequests" -f $gitUri.Scheme, $gitUri.Host, $gitUri.Port, $gitOrganization, $gitProject
        Invoke-RestMethod -Method Post -Uri ($adoApiUrl + "?api-version=7.0") -Body ($jsonBody | ConvertTo-Json -Depth 10) -Headers $header -ContentType "application/json"
    }
    "bitbucket"
    {
		# Parse url
        $gitOrganization = $gitUri.AbsolutePath
        $gitOrganization = $gitOrganization.Substring(1)
		$gitOrganization = $gitOrganization.Substring(0, $gitOrganization.IndexOf("/"))
        $gitProject = $gitUri.AbsolutePath.Replace($gitOrganization, "").Replace("//", "")
        
        # Check to see if Repo Name ends with .git
        if ($gitProject.EndsWith(".git"))
        {
        	# Strip off the last part
            $gitProject = $gitProject.Replace(".git", "")
        }

        # Construct Headers
        $header = @{
        	Authorization = "Bearer $gitPassword"
        }
        
        # Construct API url
        $bitbucketApiUrl = "{0}://api.{1}:{2}/2.0/repositories/{3}/{4}/pullrequests" -f $gitUri.Scheme, $gitUri.Host, $gitUri.Port, $gitOrganization, $gitProject
        
		# Construct json body
        $jsonBody = @{
        	title = "PR from Octopus Deploy"
            source = @{
            	branch = @{
                	name = $gitSourceBranch
                }
            }
            destination = @{
            	branch = @{
                	name = $gitDestinationBranch
                }
            }
        }
        
        # Create PR
        Invoke-RestMethod -Method Post -Uri $bitbucketApiUrl -Headers $header -Body ($jsonBody | ConvertTo-Json -Depth 10) -ContentType "application/json"
    }
    "github"
    {
        # Parse URL
        $gitRepoOwner = $gitUri.AbsolutePath.Substring(1, $gitUri.AbsolutePath.LastIndexOf("/") - 1)
        $gitRepoName = $gitUri.AbsolutePath.Substring($gitUri.AbsolutePath.LastIndexOf("/") + 1 )
        
        # Check to see if Repo Name ends with .git
        if ($gitRepoName.EndsWith(".git"))
        {
        	# Strip off the last part
            $gitRepoName = $gitRepoName.Replace(".git", "")
        }
        
        # Construct API endpoint
        $githubApiUrl = "{0}://api.{1}:{2}/repos/{3}/{4}/pulls" -f $gitUri.Scheme, $gitUri.Host, $gitUri.Port, $gitRepoOwner, $gitRepoName
        
        # Construct Headers
        $header = @{
        	Authorization = "Bearer $gitPassword"
            Accept = "application/vnd.github+json"
            "X-Github-Api-Version" = "2022-11-28"
        }
        
        # Construct body
        $jsonBody = @{
        	title = "PR from Octopus Deploy"
            body = "PR from #{Octopus.Project.Name} release version #{Octopus.Release.Number}"
            head = $gitSourceBranch
            base = $gitDestinationBranch
        }
        
        # Create the pull request
        Invoke-RestMethod -Method Post -Uri $gitHubApiUrl -Headers $header -Body ($jsonBody | ConvertTo-Json -Depth 10)
    }
    "gitlab"
    {
		# Get project name
        $gitlabProjectName = $gitUrl.SubString($gitUrl.LastIndexOf("/") + 1)
        
        # Parse uri
        $gitlabApiUrl = "{0}://{1}:{2}/api/v4/users/{3}/projects" -f $gitUri.Scheme, $gitUri.Host, $gitUri.Port, $gitUser
        
        # Check to see if it ends in .git
        if ($gitlabProjectName.EndsWith(".git"))
        {
        	# Strip that part off
            $gitlabProjectName = $gitlabProjectName.Replace(".git", "")
        }
        
        # Create header
        $header = @{ "PRIVATE-TOKEN" = $gitPassword }
        
        # Get the project
        $gitlabProject = (Invoke-RestMethod -Method Get -Uri $gitlabApiUrl -Headers $header) | Where-Object {$_.Name -eq $gitlabProjectName}
        
        # Create the merge request
         $gitlabApiUrl = "{0}://{1}:{2}/api/v4/projects/{3}/merge_requests?source_branch={4}&target_branch={5}&target_project_id={3}&title={6}" -f $gitUri.Scheme, $gitUri.Host, $gitUri.Port, $gitlabProject.id, $gitSourceBranch, $gitDestinationBranch, "PR from #{Octopus.Project.Name} release version #{Octopus.Release.Number}"
        Invoke-RestMethod -Method Post -Uri $gitlabApiUrl -Headers $header
    }
}

<#
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
Invoke-Git -GitCommand "config" -AdditionalArguments @("user.name", $gitAuthorName) #-GitFolder "$($PWD)/$($folderName)"
Invoke-Git -GitCommand "config" -AdditionalArguments @("user.email", $gitAuthorEmail) #-GitFolder "$($PWD)/$($folderName)"


# Push the new tag
Invoke-Git -Gitcommand "request-pull" -AdditionalArguments @("$gitSourceBranch", $gitUrl, "$gitDestinationBranch") -GitFolder "$($PWD)/$($folderName)"    
#>