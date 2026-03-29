[int]$timeoutSec = $null
if(-not [int]::TryParse($Timeout, [ref]$timeoutSec)) { $timeoutSec = 60 }

if($Source -eq $null) {
    $input = @{AuthorizationToken = $AuthorizationToken; Title = $Title; Body = $Body }
}
else {
    $input = @{AuthorizationToken = $AuthorizationToken; Title = $Title; Body = $Body; Source = $Source }
}

Invoke-RestMethod -Method Post -Uri "https://pushalot.com/api/sendmessage" -Body $input -TimeoutSec $timeoutSec 