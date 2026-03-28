$ip = $OctopusParameters['IP']
$hostName = $OctopusParameters['HostName']

$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$hosts = Get-Content $hostsPath
$match = $hosts -match ("^\s*$ip\s+$hostName" -replace '\.', '\.')
$hostsEntry = "$ip`t$hostName"

If ($match) {
write-host $hostsPath $hostsEntry " exist, then it will be removed."
}
else
{
write-host $hostsPath $hostsEntry "not exist"
Exit
}

(Get-Content -Path $hostsPath) |
    ForEach-Object {$_ -Replace "$hostsEntry"} |
        Set-Content -Path $hostsPath -Verbose