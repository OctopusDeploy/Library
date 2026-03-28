[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$solarwindsHost =  $OctopusParameters['Host']
$node =  $OctopusParameters['NodeId']
$application =  $OctopusParameters['ApplicationId']
$username =  $OctopusParameters['Username']
$password =  $OctopusParameters['Password']

Write-Host "Starting Solarwinds monitoring for node " + $node

if ($node -ne "")
{
    $success = $false
    try
    {
        $body = "[""$node""]"
        $header = @{}
        $header.Add("Authorization", "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password)))
        $uri = "https://" + $solarwindsHost + ":17778/SolarWinds/InformationService/v3/Json/Invoke/Orion.Nodes/Remanage"

        Write-Host "Sending request $body to $uri"

        $response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -Headers $header -ContentType "application/json" -UseBasicParsing

        if ($response.StatusCode -eq 200)
        {
            $success = $true
        }
    }
    catch
    {
        Write-Host "Something went wrong:"
        Write-Host $_.Exception
    }

    if (!$success)
    {
        throw "Remanaging node failed."
    }

    Write-Host "Remanaged node $node."
}

if ($application -ne "")
{
    $success = $false
    try
    {
        $body = "[""$application""]"
        $header = @{}
        $header.Add("Authorization", "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password)))
        $uri = "https://" + $solarwindsHost + ":17778/SolarWinds/InformationService/v3/Json/Invoke/Orion.APM.Application/Remanage"

        Write-Host "Sending request $body to $uri"

        $response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -Headers $header -ContentType "application/json" -UseBasicParsing

        if ($response.StatusCode -eq 200)
        {
            $success = $true
        }
    }
    catch
    {
        Write-Host "Something went wrong:"
        Write-Host $_.Exception
    }

    if (!$success)
    {
        throw "Remanaging application failed."
    }

    Write-Host "Remanaged application $application."
}