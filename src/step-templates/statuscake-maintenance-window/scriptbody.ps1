$apiKey = $OctopusParameters["StatusCake.ApiKey"]
$username = $OctopusParameters["StatusCake.Username"]
$name = $OctopusParameters["StatusCake.Name"]
$tid = $OctopusParameters["StatusCake.TestIds"]
$timezone = $OctopusParameters["StatusCake.Timezone"]
$length = $OctopusParameters["StatusCake.Length"]

$now = (Get-Date).ToUniversalTime()
$start = [int64](Get-Date($now) -UFormat %s)
$end = [int64](Get-Date($now.AddMinutes($length)) -UFormat %s)

$headers = @{
    "API" = $apiKey;
    "Username" = $username
}

$body = @{
    "name" = $name;
    "start_unix" = $start;
    "end_unix" = $end;
    "raw_tests" = $tid;
    "timezone" = $timezone;
}

Invoke-WebRequest -Uri https://app.statuscake.com/API/Maintenance/Update -Method POST -Headers $headers -Body $body -UseBasicParsing