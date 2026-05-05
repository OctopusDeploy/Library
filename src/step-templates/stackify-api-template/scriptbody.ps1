if (!$hostApi) { $hostApi= 'https://api.stackify.net' }

if ($OctopusParameters["Octopus.Deployment.Error"] -eq $null)
{
$post = $hostApi.TrimEnd('/') + '/api/v1/deployments/' + $action
}
else
{
$post = $hostApi.TrimEnd('/') + '/api/v1/deployments/cancel'
}
# build the authorization header

$headers = @{'authorization'='ApiKey ' + $apiKey}

# build the body of the post

if (!$name) { $name = $version }

$bodyObj = @{ Version=$version; AppName=$app; EnvironmentName=$env; }

if ($action -eq "start" -or $action -eq "complete"){

        $bodyObj.Name = $name

        if ($uri) { $bodyObj.Uri = $uri }

        if ($branch) { $bodyObj.Branch = $branch }

        if ($commit) { $bodyObj.Commit = $commit }

}

$body = ConvertTo-Json $bodyObj

# send the request
Invoke-WebRequest -Uri $post -Method POST -ContentType "application/json" -Headers $headers -Body $body -UseBasicParsing