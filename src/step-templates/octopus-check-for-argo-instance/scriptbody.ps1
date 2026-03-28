# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Define variables
$isArgoPresent = $false

# Check to see if the Octopus.Web.ServerUri variable has a value
if (![string]::IsNullOrWhitespace($OctopusParameters["Octopus.Web.ServerUri"]))
{
    $baseUrl = $OctopusParameters["Octopus.Web.ServerUri"]
}
else
{
    $baseUrl = $OctopusParameters["Octopus.Web.BaseUrl"]
}

# Validate parameters
if ([string]::IsNullOrWhitespace($OctopusParameters["Template.Octopus.API.Key"]) -or -not $OctopusParameters["Template.Octopus.API.Key"].StartsWith("API-"))
{
    Write-Highlight "An API Key was not provided, unable to check to see if there are any Argo CD instances registered in this space."
    Write-Highlight "See the [Octopus documentation](https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key) for details on creating API keys."
    Write-Highlight "Once you have an API key, add it to the $($OctopusParameters['Octopus.Step.Name']) step to enable the ability to check for Argo CD instances in this space."
}
else
{
    $header = @{ "X-Octopus-ApiKey" = $OctopusParameters["Template.Octopus.API.Key"] }

    # Get registered Argo CD instances
    $argoInstances = Invoke-RestMethod -Method Get -Uri "$($baseUrl)/api/#{Octopus.Space.Id}/argocdinstances/summaries" -Headers $header

    # Check the returned values
    if ($argoInstances.Resources.Count -gt 0)
    {
        Write-Highlight "Found $($argoInstances.Resources.Count) Argo instance(s) registered!"
        $isArgoPresent = $true
    }
    else
    {
        Write-Highlight "No Argo CD instances registered to space $($OctopusParameters['Octopus.Space.Name']).  Please [register an Argo CD instance](https://octopus.com/docs/argo-cd/instances) with this space."
    }
}

# Set output variable
Set-OctopusVariable -Name ArgoPresent -Value $isArgoPresent