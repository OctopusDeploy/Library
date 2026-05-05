[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$solarwindsHost =  $OctopusParameters['Host']
$node =  $OctopusParameters['NodeId']
$application =  $OctopusParameters['ApplicationId']
$timeout = [int] $OctopusParameters['RemanageMinutes']
$username =  $OctopusParameters['Username']
$password =  $OctopusParameters['Password']

if ($node -ne "")
{
    Write-Host "Stopping Solarwinds monitoring for node $node"

    $success = $false
    try
    {
        $now = (Get-Date).ToUniversalTime().AddSeconds(5);
        $remanage = $now.AddMinutes($timeout);
        $nowString = $now.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $remanageString = $remanage.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $body = "[""$node"", ""$nowString"", ""$remanageString"", ""false""]"
        $header = @{}
        $header.Add("Authorization", "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password)))
        $uri = "https://" + $solarwindsHost + ":17778/SolarWinds/InformationService/v3/Json/Invoke/Orion.Nodes/Unmanage"

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
        throw "Unmanaging node failed."
    }

    Write-Host "Unmanaged node $node. Will automatically remanage at $remanage.ToString()"
}

if ($application -ne "")
{
    Write-Host "Stopping Solarwinds monitoring for application $application"

    $success = $false
    try
    {
        $now = (Get-Date).ToUniversalTime().AddSeconds(5);
        $remanage = $now.AddMinutes($timeout);
        $nowString = $now.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $remanageString = $remanage.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $body = "[""$application"", ""$nowString"", ""$remanageString"", ""false""]"
        $header = @{}
        $header.Add("Authorization", "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password)))
        $uri = "https://" + $solarwindsHost + ":17778/SolarWinds/InformationService/v3/Json/Invoke/Orion.APM.Application/Unmanage"

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
        throw "Unmanaging application failed."
    }

    Write-Host "Unmanaged application $application. Will automatically remanage at $remanage.ToString()"
}