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
    return ,$items
}

$automaticResponseOctopusUrl = $OctopusParameters['AutomateResponse.Octopus.Url']
$automaticResponseApiKey = $OctopusParameters['AutomateResponse.Api.Key']
$automaticResponseReasonNotes = $OctopusParameters['AutomateResponse.Reason.Notes']
$automaticResponseManualInterventionResponseType = $OctopusParameters['AutomateResponse.ManualIntervention']
$automaticResponseGuidedFailureResponseType = $OctopusParameters['AutomateResponse.GuidedFailure']
$header = @{ "X-Octopus-ApiKey" = $automaticResponseApiKey }

# Validate response type input
if (![string]::IsNullOrWhitespace($automaticResponseManualInterventionResponseType) -and ![string]::IsNullOrWhitespace($automaticResponseGuidedFailureResponseType))
{
	# Fail step
    Write-Error "Cannot have both a Manual Intervention and Guided Failure selections."
}

if ([string]::IsNullOrWhitespace($automaticResponseManualInterventionResponseType) -and [string]::IsNullOrWhitespace($automaticResponseGuidedFailureResponseType))
{
	# Fail step
    Write-Error "Please select either a Manual Intervention or Guided Failure response type."
}

# Get space
$spaceId = $OctopusParameters['Octopus.Space.Id']

# Get project
$projectId = $OctopusParameters['Octopus.Project.Id']

# Get the environment
$environmentId = $OctopusParameters['Octopus.Environment.Id']

if (![string]::IsNullOrWhitespace($automaticResponseGuidedFailureResponseType))
{
# Get currently executing deployments for project - this is for Guided Failure as they're in an executing state
  Write-Host "Searching for executing deployments ..."
  $executingDeployments = Get-OctopusItems -OctopusUri "$automaticResponseOctopusUrl/api/$($spaceId)/deployments?projects=$($projectId)&taskState=Executing&environments=$($environmentId)" -ApiKey $automaticResponseApiKey
}

if (![string]::IsNullOrWhitespace($automaticResponseManualInterventionResponseType))
{
  Write-Host "Searching for queued deployments ..."
  # Get queued deployments - this is for 
  $executingDeployments = Get-OctopusItems -OctopusUri "$automaticResponseOctopusUrl/api/$($spaceId)/deployments?projects=$($projectId)&taskState=Queued&environments=$($environmentId)" -ApiKey $automaticResponseApiKey
}

# Check to see if anything was returned for the environment
if ($executingDeployments -is [array])
{
  # Loop through executing deployments
  foreach ($deployment in $executingDeployments)
  {
      # Get object for manual intervention
      Write-Host "Checking $($deployment.Id) for manual interventions ..."
      $manualIntervention = Get-OctopusItems -OctopusUri "$automaticResponseOctopusUrl/api/$($spaceId)/interruptions?regarding=$($deployment.Id)&pendingOnly=true" -ApiKey $automaticResponseApiKey

      # Check to see if a manual intervention was returned
      if ($null -ne $manualIntervention.Id)
      {
          # Take responsibility
          Write-Host "Auto taking resonsibility for manual intervention ..."
          Invoke-RestMethod -Method Put -Uri "$automaticResponseOctopusUrl/api/$($spaceId)/interruptions/$($manualIntervention.Id)/responsible" -Headers $header

          # Create response object
          $jsonBody = @{
              Notes = $automaticResponseReasonNotes
          }

          # Check to see if manual intervention is empty
          if (![string]::IsNullOrWhiteSpace($automaticResponseManualInterventionResponseType))
          {
              # Add the manual intervention type
              Write-Host "Submitting $automaticResponseManualInterventionResponseType as response ..."
              $jsonBody.Add("Result", $automaticResponseManualInterventionResponseType)
          }

          # Check to see if the guided failure is empty
          if (![string]::IsNullOrWhiteSpace($automaticResponseGuidedFailureResponseType))
          {
              # Add the guided failure response
              Write-Host "Submitting $automaticResponseGuidedFailureResponseType as response ..."
              $jsonBody.Add("Guidance", $automaticResponseGuidedFailureResponseType)
          }

          # Post to server
          Invoke-RestMethod -Method Post -Uri "$automaticResponseOctopusUrl/api/$($spaceId)/interruptions/$($manualIntervention.Id)/submit" -Body ($jsonBody | ConvertTo-Json -Depth 10) -Headers $header
      }
  }
}