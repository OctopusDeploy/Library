$token  = [System.Text.Encoding]::UTF8.GetBytes($sentryApiKey+":")
$base64Token = [System.Convert]::ToBase64String($token)

Write-Host $base64Token

ForEach ($project in $projects.Split(';'))  
{
    $url = "https://app.getsentry.com/api/0/projects/$organization/$project/releases/"
    Write-Host $url
    
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Basic $base64Token")
    
    $body = @{ "version" = $OctopusParameters['Octopus.Release.Number'] }
    
    $body = ConvertTo-Json $body
    
    Write-Host $body
    Try
    {
        $response = Invoke-RestMethod -Method Post -Uri "$url" -Body $body -Headers $headers -ContentType "application/json"
        Write-Host $response
    }
    Catch [System.Net.WebException] 
    {
        Write-Host $_
        if($_.Exception.Response.StatusCode.Value__ -ne 400)
        {
            Throw
        }
    }
    if ($resolveIssues)
    {
        $resolveBody = '{"status":"resolved"}'
        Write-Host $resolveBody
        $url = "https://app.getsentry.com/api/0/projects/$organization/$project/groups/"
        Write-Host $url
        $response = Invoke-RestMethod -Method Put -Uri "$url" -Body $resolveBody -Headers $headers -ContentType "application/json"
        Write-Host $response
    }
}