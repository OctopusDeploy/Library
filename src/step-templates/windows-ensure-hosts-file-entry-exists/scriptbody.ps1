$ip = $OctopusParameters['IP']
$hostName = $OctopusParameters['HostName']

$hostsPath = "$env:windir\System32\drivers\etc\hosts"

$hosts = Get-Content $hostsPath

$match = $hosts -match ("^\s*$ip\s+$hostName" -replace '\.', '\.')

If ($match) { Exit }

$hostsEntry = "$ip`t$hostName"

If ([IO.File]::ReadAllText($hostsPath) -notmatch "\r\n\z") { $hostsEntry = [environment]::newline + $hostsEntry }

Add-Content $hostsPath $hostsEntry
