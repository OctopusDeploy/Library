$errorCollection = @()
$setupValid = $false

Write-Host "Checking for deployment targets ..."

try
{
    # Check to make sure targets have been created
    if ([string]::IsNullOrWhitespace("#{Octopus.Web.ServerUri}"))
    {
        $octopusUrl = "#{Octopus.Web.BaseUrl}"
    }
    else
    {
        $octopusUrl = "#{Octopus.Web.ServerUri}"
    }

    $apiKey = "#{CheckTargets.Octopus.Api.Key}"
    $role = "#{CheckTargets.Octopus.Role}"
    $message = "#{CheckTargets.Message}"

    if (![string]::IsNullOrWhitespace($apiKey) -and $apiKey.StartsWith("API-"))
    {
        $spaceId = "#{Octopus.Space.Id}"
        $headers = @{ "X-Octopus-ApiKey" = "$apiKey" }

        try
        {
            $roleTargets = Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/$spaceId/machines?roles=$role" -Headers $headers
            if ($roleTargets.Items.Count -lt 1)
            {
                $errorCollection += @("Expected at least 1 target for tag $role, but found $( $roleTargets.Items.Count ). $message")
            }
        }
        catch
        {
            $errorCollection += @("Failed to retrieve role targets: $( $_.Exception.Message )")
        }

        if ($errorCollection.Count -gt 0)
        {
            foreach ($item in $errorCollection)
            {
                Write-Highlight "$item"
            }
        }
        else
        {
            $setupValid = $true
            Write-Host "Setup valid!"
        }
    }
    else
    {
        Write-Highlight "The project variable CheckTargets.Octopus.Api.Key has not been configured, unable to check deployment targets."
        Write-Highlight "See the [Octopus documentation](https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key) for details on creating API keys."
        Write-Highlight "Once you have an API key, add it to the $($OctopusParameters['Octopus.Step.Name']) step to enable the ability to check for targets in this space."
    }

    Set-OctopusVariable -Name SetupValid -Value $setupValid
} catch {
    Write-Verbose "Fatal error occurred:"
    Write-Verbose "$($_.Exception.Message)"
}