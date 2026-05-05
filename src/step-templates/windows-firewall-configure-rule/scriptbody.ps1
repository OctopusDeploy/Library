$ruleName = $OctopusParameters['RuleName']
$localPort = $OctopusParameters['LocalPort']
$remotePort = $OctopusParameters['RemotePort']
$protocol = $OctopusParameters['Protocol']
$direction = $OctopusParameters['Direction']

# Remove any existing rule

Write-Host "Removing existing rule"
netsh advfirewall firewall delete rule name="$ruleName" dir=$direction

# Add new rule

Write-Host "Adding new rule"
netsh advfirewall firewall add rule name="$ruleName" dir=$direction action=allow protocol=$protocol localport=$localPort remoteport=$remotePort