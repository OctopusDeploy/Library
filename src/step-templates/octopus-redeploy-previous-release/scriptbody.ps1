function Get-OctopusItems
{
	# Define parameters
    param(
    	$OctopusUri,
        $ApiKey,
        $SkipCount = 0
    )
    
    # Define working variables
    $items = @()
    $skipQueryString = ""
    $headers = @{"X-Octopus-ApiKey"="$ApiKey"}

    # Check to see if there there is already a querystring
    if ($octopusUri.Contains("?"))
    {
        $skipQueryString = "&skip="
    }
    else
    {
        $skipQueryString = "?skip="
    }

    $skipQueryString += $SkipCount
    
    # Get intial set
    Write-Host "Calling $OctopusUri$skipQueryString"
    $resultSet = Invoke-RestMethod -Uri "$($OctopusUri)$skipQueryString" -Method GET -Headers $headers

    # Check to see if it returned an item collection
    if ($null -ne $resultSet.Items)
    {
        # Store call results
        $items += $resultSet.Items
    
        # Check to see if resultset is bigger than page amount
        if (($resultSet.Items.Count -gt 0) -and ($resultSet.Items.Count -eq $resultSet.ItemsPerPage))
        {
            # Increment skip count
            $SkipCount += $resultSet.ItemsPerPage

            # Recurse
            $items += Get-OctopusItems -OctopusUri $OctopusUri -ApiKey $ApiKey -SkipCount $SkipCount
        }
    }
    else
    {
        return $resultSet
    }
    
    # Return results
    return $items
}

# Define variables
$octopusApiKey = $OctopusParameters['redeploy.api.key']
$octopusUri = $OctopusParameters['redeploy.octopus.server.uri']
$octopusReleaseNumber = $OctopusParameters['redeploy.release.number']
$octopusReleaseId = $null
$header =  @{ "X-Octopus-ApiKey" = $octopusApiKey }
$spaceId = $OctopusParameters['Octopus.Space.Id']
$environmentId = $OctopusParameters['Octopus.Environment.Id']
$projectId = $OctopusParameters['Octopus.Project.Id']
$promptedVariables = $OctopusParameters['redeploy.prompted.variables']
$usePreviousPromptedVariables = [System.Convert]::ToBoolean($OctopusParameters['redeploy.prompted.useexisting'])
$deploymentFormValues = @{}

if ($octopusUri.EndsWith("/") -eq $true)
{
  # Add trailing slash
  $octopusUri = $octopusUri.Substring(0, ($octopusUri.Length - 1))
}

# Check to see if a release number was provided
if ([string]::IsNullOrWhitespace($octopusReleaseNumber))
{
  # Get the previous release number
  $octopusReleaseId = $OctopusParameters['Octopus.Release.PreviousForEnvironment.Id']
  
  $release = Get-OctopusItems -OctopusUri "$octopusUri/api/$spaceId/releases/$octopusReleaseId" -ApiKey $octopusApiKey
}
else
{
  # Get the specific release
  $release = Get-OctopusItems -OctopusUri "$octopusUri/api/$spaceId/projects/$projectId/releases?searchByVersion=$octopusReleaseNumber" -ApiKey $octopusApiKey
  
  # Record the id
  $octopusReleaseId = $release.Id
}  
  
# Verify result
if ($null -ne $release)
{
  # Get deployments
  $deployments = Get-OctopusItems -OctopusUri "$octopusUri/api/$spaceId/releases/$($release.Id)/deployments" -ApiKey $octopusApiKey
   
  # Ensure this release has been deployed to this environment
  $deployment = ($deployments | Where-Object {$_.EnvironmentId -eq $environmentId})
    
  if ($null -eq $deployment)
  {
    Write-Error "Error: $octopusReleaseNumber has not been deployed to $($OctopusParameters['Octopus.Environment.Name'])!"
  }
    
  # Get the task
  if ($deployment.Links.Task -is [array])
  {
    # Get the last attempt
    $taskLink = $deployment.Links.Task[-1]
  }
  else
  {
    $taskLink = $deployment.Links.Task
  }
  
  $serverTask = Invoke-RestMethod -Method Get -Uri "$octopusUri$($taskLink)" -Headers $header
    
  # Ensure it was successful before continuing
  if ($serverTask.State -eq "Failed")
  {
    Write-Error "The previous deployment of $($release.Version) to $($OctopusParameters['Octopus.Environment.Name']) was not successful, unable to re-deploy."
  }
  
  try
  {
    $deploymentVariables = Invoke-RestMethod -Method Get -Uri "$octopusUri/api/$spaceId/variables/variableset-$($serverTask.Arguments.DeploymentId)" -Headers $header
  }
  catch
  {
    if ($_.Exception.Response.StatusCode -eq "NotFound")
    {
      $deploymentVariables = $null
    }
    else
    {
      throw
    }
  }
  
  # Get only prompted variables
  $deploymentVariables = ($deploymentVariables.Variables | Where-Object {$null -ne $_.Prompt})
}
else
{
  Write-Error "Unable to find release version $octopusReleaseNumber!"
}

# Check to see if there prompted variables that need to be included
if ($usePreviousPromptedVariables -or ![string]::IsNullOrWhitespace($promptedVariables))
{
    # Ensure the previous deployment variables were retrieved
    if ($null -eq $deploymentVariables)
    {
      throw "Error: Unable to retrieve previous deployment variables!"
    }
    
    if ($usePreviousPromptedVariables)
    {
      # Create list
      $promptedValueList = @()
      foreach ($variable in $deploymentVariables)
      {
        $promptedValueList += "$($variable.Name)=$($variable.Value)"
      }
    }
    else
    {
      $promptedValueList = @(($promptedVariables -Split "`n").Trim())
    }

    # Get deployment preview for prompted variables
    $deploymentPreview = Invoke-RestMethod "$OctopusUri/api/$spaceId/releases/$octopusReleaseId/deployments/preview/$($environmentId)?includeDisabledSteps=true" -Headers $header  
   
    foreach($element in $deploymentPreview.Form.Elements)
    {
        $nameToSearchFor = $element.Control.Name
        $uniqueName = $element.Name
        $isRequired = $element.Control.Required
    
        $promptedVariablefound = $false
    
        Write-Host "Looking for the prompted variable value for $nameToSearchFor"
        foreach ($promptedValue in $promptedValueList)
        {
            $splitValue = $promptedValue -Split "="
            Write-Host "Comparing $nameToSearchFor with provided prompted variable $($promptedValue[$nameToSearchFor])"
            if ($splitValue.Length -gt 1)
            {
                if ($nameToSearchFor -eq $splitValue[0].Trim())
                {
                    Write-Host "Found the prompted variable value $nameToSearchFor"
                    $deploymentFormValues[$uniqueName] = $splitValue[1].Trim()
                    $promptedVariableFound = $true
                    break
                }
            }
        }
    
        if ($promptedVariableFound -eq $false -and $isRequired -eq $true)
        {
            Write-Highlight "Unable to find a value for the required prompted variable $nameToSearchFor, exiting"
            Exit 1
        }
    }
 
}

# Create json object to deploy the release
$deploymentBody = @{
  ReleaseId = $octopusReleaseId
  EnvironmentId = $environmentId
}

# Check to see if there were any Prompted Variables
if ($deploymentFormValues.Count -gt 0)
{
  $deploymentBody.Add("FormValues", $deploymentFormValues)
}

# Submit deployment
Write-Host "Submitting release $($release.Version) to $($OctopusParameters['Octopus.Environment.Name'])"
$submittedRelease = (Invoke-RestMethod -Uri "$octopusUri/api/$spaceId/deployments" -Method POST -Headers $header -Body ($deploymentBody | ConvertTo-Json -Depth 10))

Write-Host "[View the re-deployment]($octopusUri$($submittedRelease.Links.Web))"