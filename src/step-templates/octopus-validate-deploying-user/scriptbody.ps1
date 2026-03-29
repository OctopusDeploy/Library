$releaseId = $OctopusParameters["Octopus.Release.Id"]
$currentDeployerId = $OctopusParameters["Octopus.Deployment.CreatedBy.Id"]
$userName = $OctopusParameters["Octopus.Deployment.CreatedBy.Username"]
$environmentId = $OctopusParameters["Octopus.Environment.Id"]
$spaceId = $OctopusParameters["Octopus.Space.Id"]
$octopusURL = $OctopusParameters["ovdu_octopusURL"]
$octopusAPIKey = $OctopusParameters["ovdu_octopusAPIKey"]
$precedingEnvironment = $OctopusParameters["ovdu_precedingEnvironment"]

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$deploymentDetails = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($spaceId)/releases/$($releaseId)/deployments/" -Headers $header)

# Get details for deployment to preceding environment
$allEnvironments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($spaceId)/environments" -Headers $header)
$environmentItem = $allEnvironments.Items | where-object { $_.Name -eq $precedingEnvironment }
$environmentId = $environmentItem.Id

# Load all deploys to the previous environment
$environmentDeploys = $deploymentDetails.Items | Where-Object {$_.EnvironmentId -eq $environmentId}

# Iterate deployments to the previous environment to validate current deployer
foreach($prevdeployment in $environmentDeploys)
    {
    	if($prevDeployment.Id -eq $OctopusParameters["Octopus.Deployment.Id"])
        {continue}
    	else
        {
    		if($prevdeployment.DeployedById -eq $currentDeployerId )
        	{
            	Write-Highlight "$userName previously deployed this project to $precedingEnvironment - deployment cancelled."
            	Throw "$userName previously deployed this project to $precedingEnvironment - deployment cancelled."
        	}
        }
    }