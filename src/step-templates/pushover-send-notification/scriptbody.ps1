[int]$timeoutSec = $null
if(-not [int]::TryParse($Timeout, [ref]$timeoutSec)) { $timeoutSec = 60 }

if($Title -eq $null) {
    $input = @{token = $APIToken; user = $UserKey; message = $Message; priority = $Priority }
}
else {
    $input = @{token = $APIToken; user = $UserKey; message = $Message; priority = $Priority; title = $Title }
}

Invoke-RestMethod -Method Post -Uri "https://api.pushover.net/1/messages.json" -Body $input -TimeoutSec $timeoutSec 