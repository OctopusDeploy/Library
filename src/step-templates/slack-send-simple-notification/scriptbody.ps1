$payload = @{
    channel = $OctopusParameters['ssn_Channel']
    username = $OctopusParameters['ssn_Username'];
    icon_url = $OctopusParameters['ssn_IconUrl'];
    link_names = "true";
    attachments = @(
        @{
            mrkdwn_in = $('pretext', 'text');
            pretext = $OctopusParameters['ssn_Title'];
            text = $OctopusParameters['ssn_Message'];
            color = $OctopusParameters['ssn_Color'];
        }
    )
}

try {
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
    if ($PSVersionTable.PSVersion.Major -ge 6)
    {
        Invoke-Restmethod -Method POST -Body ($payload | ConvertTo-Json -Depth 4) -Uri $OctopusParameters['ssn_HookUrl']
    }
    else
    {
        Invoke-Restmethod -Method POST -Body ($payload | ConvertTo-Json -Depth 4) -Uri $OctopusParameters['ssn_HookUrl'] -UseBasicParsing
    }
} catch {
    Write-Host "An error occurred while attempting to send Slack notification"
    Write-Host $_.Exception
    Write-Host $_
    throw
}