# We assume that deployments to the production environments alternate between green and blue.
# For example, if the last production deployment was to blue the next one should be to the green environment.
# This check is used to provide a warning if a production environment is deployed to twice in a row.

$octopusUrl = ""

# Check to make sure targets have been created
if ([string]::IsNullOrWhitespace("#{Octopus.Web.ServerUri}"))
{
    $octopusUrl = "#{Octopus.Web.BaseUrl}"
}
else
{
    $octopusUrl = "#{Octopus.Web.ServerUri}"
}

if (-not "#{BlueGreen.Octopus.Api.Key}".StartsWith("API-")) {
    Write-Host "The BlueGreen.Octopus.Api.Key variable has not been defined. We can not validate the deployment environment."
    Write-Highlight "See the [Octopus documentation](https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key) for details on creating API keys."
    Write-Highlight "Once you have an API key, add it to the $($OctopusParameters['Octopus.Step.Name']) step to enable the ability to check for deployments to blue/green environments in this space."
    exit 0
}

if ([string]::IsNullOrWhiteSpace("#{BlueGreen.Environment.Blue.Name}")) {
    Write-Host "The BlueGreen.Environment.Blue.Name variable has not been defined. We can not validate the deployment environment."
    exit 0
}

if ([string]::IsNullOrWhiteSpace("#{BlueGreen.Environment.Green.Name}")) {
    Write-Host "The BlueGreen.Environment.Green.Name variable has not been defined. We can not validate the deployment environment."
    exit 0
}

$header = @{ "X-Octopus-ApiKey" = "#{BlueGreen.Octopus.Api.Key}" }

# Get environment ID
$blueEnvironmentName = "#{BlueGreen.Environment.Blue.Name}"
$blueEnvironments = Invoke-RestMethod -Uri "$octopusURL/api/#{Octopus.Space.Id}/environments?partialName=$([uri]::EscapeDataString($blueEnvironmentName))&skip=0&take=100" -Headers $header
$blueEnvironment = $blueEnvironments.Items | Where-Object { $_.Name -eq $blueEnvironmentName } | Select-Object -First 1

if ($null -eq $blueEnvironment) {
    Write-Host "Could not find an environment called $blueEnvironmentName. We can not validate the deployment environment."
    exit 0
}

$greenEnvironmentName = "#{BlueGreen.Environment.Green.Name}"
$greenEnvironments = Invoke-RestMethod -Uri "$octopusURL/api/#{Octopus.Space.Id}/environments?partialName=$([uri]::EscapeDataString($greenEnvironmentName))&skip=0&take=100" -Headers $header
$greenEnvironment = $greenEnvironments.Items | Where-Object { $_.Name -eq $greenEnvironmentName } | Select-Object -First 1

if ($null -eq $greenEnvironment) {
    Write-Host "Could not find an environment called $greenEnvironment. We can not validate the deployment environment."
    exit 0
}

# Get deployments for the environment and project, excluding the current deployment
$blueDeploymentsUri = "$octopusUrl/api/#{Octopus.Space.Id}/deployments?environments=$($blueEnvironment.Id)&projects=#{Octopus.Project.Id}&take=2"
$blueLatestDeployment = Invoke-RestMethod -Uri $blueDeploymentsUri -Headers $header | Select-Object -ExpandProperty Items | Where-Object { $_.Id -ne "#{Octopus.Deployment.Id}" }

$greenDeploymentsUri = "$octopusUrl/api/#{Octopus.Space.Id}/deployments?environments=$($greenEnvironment.Id)&projects=#{Octopus.Project.Id}&take=2"
$greenLatestDeployment = Invoke-RestMethod -Uri $greenDeploymentsUri -Headers $header | Select-Object -ExpandProperty Items | Where-Object { $_.Id -ne "#{Octopus.Deployment.Id}" }

# This is the first deployment to any environment. It doesn't matter which one we go to first.
if ($greenLatestDeployment.Length -eq 0 -and $blueLatestDeployment.Length -eq 0) {
    Write-Host "Neither environment has had a deployment, so we are OK to continue"
    Set-OctopusVariable -name "SequentialDeploy" -value "False"
    exit 0
}

if ("#{Octopus.Environment.Name}" -eq $blueEnvironmentName) {
    if ($blueLatestDeployment.Length -eq 0)
    {
        Write-Host "We're deploying to blue and there are no blue deployments, so we're OK to continue"
        Set-OctopusVariable -name "SequentialDeploy" -value "False"
        exit 0
    }

    # We know we have deployed to blue at least once, but if we have never deployed to green
    # then we should not continue.
    if ($greenLatestDeployment.Length -eq 0)
    {
        Write-Host "We're deploying to blue but there are no green deployments, so we should not continue"
        Set-OctopusVariable -name "SequentialDeploy" -value "True"
        exit 0
    }
}

if ("#{Octopus.Environment.Name}" -eq $greenEnvironmentName) {
    if ($greenLatestDeployment.Length -eq 0)
    {
        Write-Host "We're deploying to green and there are no green deployments, so we're OK to continue"
        Set-OctopusVariable -name "SequentialDeploy" -value "False"
        exit 0
    }

    # We know we have deployed to green at least once, but if we have never deployed to blue
    # then we should not continue.
    if ($blueLatestDeployment.Length -eq 0)
    {
        Write-Host "We're deploying to green but there are no blue deployments, so we should not continue"
        Set-OctopusVariable -name "SequentialDeploy" -value "True"
        exit 0
    }
}

# At this point both blue and green have done at least one deployment. We need to check
# which environment had the last deployment.
$blueLastDeploy = [DateTimeOffset]::Parse($blueLatestDeployment[0].Created)
$greenLastDeploy = [DateTimeOffset]::Parse($greenLatestDeployment[0].Created)

Write-Host "Blue Last Deploy: $blueLastDeploy"
Write-Host "Green Last Deploy: $greenLastDeploy"

# We now check to see if the current environment has had the last deployment. If so,
# we have deployed to this environment twice in a row and we should block the deployment.
if ("#{Octopus.Environment.Name}" -eq $blueEnvironmentName -and $blueLastDeploy -gt $greenLastDeploy) {
    Write-Host "The last deployment was to the blue environment, so we should not deploy to it again."
    Set-OctopusVariable -name "SequentialDeploy" -value "True"
    exit 0
}

if ("#{Octopus.Environment.Name}" -eq $greenEnvironmentName -and $greenLastDeploy -gt $blueLastDeploy) {
    Write-Host "The last deployment was to the green environment, so we should not deploy to it again."
    Set-OctopusVariable -name "SequentialDeploy" -value "True"
    exit 0
}

Write-Host "We're OK to continue with the deployment."
Set-OctopusVariable -name "SequentialDeploy" -value "False"