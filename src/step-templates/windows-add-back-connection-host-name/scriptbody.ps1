$hostName = $OctopusParameters['HostName']

$key = 'HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0\'

$hostNames = get-itemproperty $key -Name BackConnectionHostNames -ErrorAction SilentlyContinue

If ($hostNames -eq $null) { new-itemproperty $key -Name BackConnectionHostNames -Value $hostName -PropertyType MultiString }

ElseIf ($hostNames.BackConnectionHostNames -notcontains  $hostName) { set-itemproperty $key -Name BackConnectionHostNames -Value ($hostNames.BackConnectionHostNames + $hostName) }
