function Slack-Rich-Notification ($notification)
{
    $payload = @{
        channel = $OctopusParameters['Channel']
        username = $OctopusParameters['Username'];
        icon_url = $OctopusParameters['IconUrl'];
        attachments = @(
            @{
            fallback = $notification["fallback"];
            color = $notification["color"];
            fields = @(
                @{
                title = $notification["title"];
                title_link = $notification["title_link"];
                value = $notification["value"];
                });
            };
        );
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Method POST -Body ($payload | ConvertTo-Json -Depth 4) -Uri $OctopusParameters['HookUrl']  -ContentType 'application/json' -UseBasicParsing
}

$OctopusBaseUri = $OctopusWebBaseUrl
$UseServerUri = [boolean]::Parse($OctopusParameters['UseServerUri']);
if ($UseServerUri) {
	$OctopusBaseUri = $OctopusWebServerUri
}

$IncludeMachineName = [boolean]::Parse($OctopusParameters['IncludeMachineName']);
if ($IncludeMachineName) {
    $MachineName = $OctopusParameters['Octopus.Machine.Name'];
    if ($MachineName) {
      $FormattedMachineName = "($MachineName)";
    }
}

if ($OctopusParameters['Octopus.Deployment.Error'] -eq $null){
    Slack-Rich-Notification @{
        title = "Success";
        title_link = "$OctopusBaseUri$OctopusWebDeploymentLink";
        value = "Deploy <$OctopusBaseUri$OctopusWebProjectLink|$OctopusProjectName> release <$OctopusBaseUri$OctopusWebReleaseLink|$OctopusReleaseNumber> to $OctopusEnvironmentName $OctopusActionTargetRoles $OctopusDeploymentTenantName $FormattedMachineName";
        fallback = "Deployed $OctopusProjectName release $OctopusReleaseNumber to $OctopusEnvironmentName successfully";
        color = "good";
    };
} else {
    Slack-Rich-Notification @{
        title = "Failed";
        title_link = "$OctopusBaseUri$OctopusWebDeploymentLink";
        value = "Deploy <$OctopusBaseUri$OctopusWebProjectLink|$OctopusProjectName> release <$OctopusBaseUri$OctopusWebReleaseLink|$OctopusReleaseNumber> to $OctopusEnvironmentName $OctopusActionTargetRoles $OctopusDeploymentTenantName $FormattedMachineName";
        fallback = "Failed to deploy $OctopusProjectName release $OctopusReleaseNumber to $OctopusEnvironmentName";
        color = "danger";
    };
}