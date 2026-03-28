$apiKey = "#{SmtpCheck.Octopus.Api.Key}"
$isSmtpConfigured = $false

if (![string]::IsNullOrWhitespace($apiKey) -and $apiKey.StartsWith("API-"))
{
    if ([String]::IsNullOrWhitespace("#{Octopus.Web.ServerUri}"))
    {
        $octopusUrl = "#{Octopus.Web.BaseUrl}"
    }
    else
    {
        $octopusUrl = "#{Octopus.Web.ServerUri}"
    }

    $uriBuilder = New-Object System.UriBuilder("$octopusUrl/api/smtpconfiguration/isconfigured")
    $uri = $uriBuilder.ToString()

    try
    {
        $headers = @{ "X-Octopus-ApiKey" = $apiKey }
        $smtpConfigured = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        $isSmtpConfigured = $smtpConfigured.IsConfigured
    }
    catch
    {
        Write-Host "Error checking SMTP configuration: $($_.Exception.Message)"
    }
}
else
{
    Write-Highlight "The project variable SmtpCheck.Octopus.Api.Key has not been configured, unable to check SMTP configuration."
    Write-Highlight "See the [Octopus documentation](https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key) for details on creating API keys."
    Write-Highlight "Once you have an API key, add it to the $($OctopusParameters['Octopus.Step.Name']) step to enable the ability to check the SMTP configuration."
}

if (-not $isSmtpConfigured)
{
    Write-Highlight "SMTP is not configured. Please [configure SMTP](https://octopus.com/docs/projects/built-in-step-templates/email-notifications#smtp-configuration) settings in Octopus Deploy."
}

Set-OctopusVariable -Name SmtpConfigured -Value $isSmtpConfigured