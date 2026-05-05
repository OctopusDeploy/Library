$payload = ($OctopusParameters['ssn_BlockObj'] | ConvertFrom-Json)
$payload | Add-Member -MemberType NoteProperty -Name channel -Value $OctopusParameters['ssn_Channel']
$payload | Add-Member -MemberType NoteProperty -Name username -Value $OctopusParameters['ssn_Username']
$payload | Add-Member -MemberType NoteProperty -Name icon_url -Value $OctopusParameters['ssn_IconUrl']
$payload | Add-Member -MemberType NoteProperty -Name link_names -Value "true"

try {
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11
    if ($PSVersionTable.PSVersion.Major -ge 6)
    {
        Invoke-Restmethod -Method POST -Body ($payload | ConvertTo-Json -Depth 10) -Uri $OctopusParameters['ssn_HookUrl']
    }
    else
    {
        Invoke-Restmethod -Method POST -Body ($payload | ConvertTo-Json -Depth 10) -Uri $OctopusParameters['ssn_HookUrl'] -UseBasicParsing
    }
} catch {
    Write-Host "An error occurred while attempting to send Slack notification"
    Write-Host $_.Exception
    Write-Host $_
    throw
}