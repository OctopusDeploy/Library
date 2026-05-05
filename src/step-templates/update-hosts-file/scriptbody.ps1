$hostsPath = "$env:windir\system32\drivers\etc\hosts"
Write-Host "Opening HOSTS file:$hostsPath"

$hostEntries = $OctopusParameters["uhf_Hosts"]
Write-Verbose "hostEntries:$hostEntries"

$lines = (Get-Content $hostsPath)

for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match "^#" -or $line -match "^[\s\t]*$") {
        continue
    }

    $line = ""

    $lines[$i] = $line
}

foreach ($hostEntry in $hostEntries.Split("`n")) {
    Write-Verbose $hostEntry
    $parts = $hostEntry.Split(",")
    $ip = $parts[0]
    Write-Verbose $ip
    $hostname = $parts[1]
    Write-Verbose $hostname
    $line = "$ip`t`t`t$hostname"
    Write-Host "Adding entry:$line"
    $lines += $line
}

Out-File -FilePath $hostsPath -Encoding ascii -InputObject $lines.Where({ $_ -ne ""}) -Force