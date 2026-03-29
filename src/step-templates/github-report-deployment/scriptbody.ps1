[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function InputParameters-Check() {
    If ([string]::IsNullOrEmpty($OctopusParameters["GitHubHash"])) {
        Write-Host "No github hash was specified, there's nothing to report then."
        exit
    }

    If ([string]::IsNullOrEmpty($OctopusParameters["GitHubUserName"])) {
        Write-Host "GitHubUserName is not set up, can't report without authentication."
        exit
    }

    If ([string]::IsNullOrEmpty($OctopusParameters["GitHubPassword"])) {
        Write-Host "GitHubPassword is not set up, can't report without authentication."
        exit
    }

    If ([string]::IsNullOrEmpty($OctopusParameters["GitHubOwner"])) {
        Write-Host "GitHubOwner is not set up, can't report without knowing the owner."
        exit
    }


    If ([string]::IsNullOrEmpty($OctopusParameters["GitHubRepoName"])) {
        Write-Host "GitHubRepoName is not set up, can't report without knowing the repo."
        exit
    }
}

function Headers-Create ([String] $username, [String] $password) {
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))

    $headers = @{
      Authorization=("Basic {0}" -f $base64AuthInfo);
      Accept="application/vnd.github.ant-man-preview+json, application/vnd.github.flash-preview+json";
    }
    return $headers
}

function GithubDeployment-Create ([String] $owner, [String] $repository, [String] $gitHubHash, [String] $environment, [String] $username, [String] $password) {
    $fullRepoName = $owner + "/" + $repository
    $projectDeploymentsUrl = "https://api.github.com/repos/$fullRepoName/deployments"
    Write-Host "Creating a deployment on GitHub on behalf of $username for repo $fullRepoName"
    $headers = Headers-Create -username $username -password $password

    $deploymentCreatePayload = @{
        "ref"=$gitHubHash;
        "auto_merge"=$False;
        "environment"=$environment;
        "description"="Octopus Deploy";
    }

    Write-Host "Calling $projectDeploymentsUrl"
    Write-Host "Payload:"
    Write-Host ($deploymentCreatePayload | Format-Table | Out-String)

    $newDeployment = Invoke-RestMethod $projectDeploymentsUrl -Method Post -Body ($deploymentCreatePayload|ConvertTo-Json) -Headers $headers
    $deploymentId=$newDeployment.id
    return $deploymentId
}

function GithubDeployment-UpdateStatus ([String] $owner, [String] $repository, [String] $deploymentId, [String] $environment, [String] $newStatus, [String] $logLink) {
    $fullRepoName = $owner + "/" + $repository
    $projectDeploymentsUrl = "https://api.github.com/repos/$fullRepoName/deployments"
    Write-Host "Setting statuses to $newStatus on $projectDeploymentsUrl"
    $headers = Headers-Create -username $username -password $password

    $statusUpdatePayload = @{
        "environment"=$environment;
        "state"=$newStatus;
        "description"="Octopus Deploy";
        "log_url"=$logLink;
        "environment_url"=$logLink;
        "auto_inactive"=$True;
    }

    $statusesUrl = "$projectDeploymentsUrl/$deploymentId/statuses"

    Write-Host "Calling $statusesUrl"
    Write-Host "Payload:"
    Write-Host ($statusUpdatePayload | Format-Table | Out-String)

    $statusResult = Invoke-RestMethod $statusesUrl -Method Post -Body ($statusUpdatePayload|ConvertTo-Json) -Headers $headers

    Write-Host "Call result:"
    Write-Host ($statusResult | Format-Table | Out-String)

}

function Status-Create() {
    If ([string]::IsNullOrEmpty($OctopusParameters["GitHubStatus"])) {
        $octopusError=$OctopusParameters["Octopus.Deployment.Error"]
        $octopusErrorDetail=$OctopusParameters["Octopus.Deployment.ErrorDetail"]

        Write-Host "Desired status is not specified. Reporting either success or error."
        Write-Host "Current Octopus.Deployment.Error is $octopusError"
        Write-Host "Current Octopus.Deployment.ErrorDetail is $octopusErrorDetail"
        $newStatus = If ([string]::IsNullOrEmpty($octopusError)) { "success" } Else { "failure" }
        Write-Host "Based on that, the status is going to be $newStatus"
        return $newStatus
    }
    else {
        Write-Host "Desired status of $newStatus is specified, using it."
        return $OctopusParameters["GitHubStatus"]
    }
}

$repoOwner=$OctopusParameters["GitHubOwner"]
$repoName=$OctopusParameters["GitHubRepoName"]
$gitHubHash=$OctopusParameters["GitHubHash"]
$username=$OctopusParameters["GitHubUserName"]
$password=$OctopusParameters["GitHubPassword"]
$environment=$OctopusParameters["Octopus.Environment.Name"]
$deploymentLink=$OctopusParameters["Octopus.Web.DeploymentLink"]
$serverUrl=$OctopusParameters["#{if Octopus.Web.ServerUri}#{Octopus.Web.ServerUri}#{else}#{Octopus.Web.BaseUrl}#{/if}"] -replace "http://", "https://"
$fullDeploymentLink="$serverUrl$deploymentLink"
$newStatus=$OctopusParameters["GitHubStatus"]
$deploymentId=$OctopusParameters["GitHubDeploymentId"]

InputParameters-Check

If ([string]::IsNullOrEmpty($deploymentId)) {
    Write-Host "No deployment id is provided."
    $deploymentId = GithubDeployment-Create -owner $repoOwner -repository $repoName -gitHubHash $gitHubHash -environment $environment -username $username -password $password

    Write-Host "Created a deployment on GitHub: #($deploymentId). Exported it as GitHubDeploymentId"
    Set-OctopusVariable -name "GitHubDeploymentId" -value $deploymentId
}

Write-Host "Using deployment id $deploymentId."

$status = Status-Create
Write-Host ""
Write-Host ""

GithubDeployment-UpdateStatus -owner $repoOwner -repository $repoName -deploymentId $deploymentId -environment $environment -newStatus $status -logLink $fullDeploymentLink
