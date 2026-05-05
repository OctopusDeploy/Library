$file = $OctopusParameters['File']
$index = $OctopusParameters['Index']
$appName = $OctopusParameters['AppName']

# Enable splunk forwarding

Set-Service SplunkForwarder -startuptype Automatic

# Create log file

if(!(Test-Path "$file"))
{
    Write-Host "Creating new log file"
    New-Item "$file" -type File -Force
}
else
{
    Write-Host "Log file already exists"
}

# Create/prepare splunk forwarder directory

$appPath = "$env:ProgramFiles\SplunkUniversalForwarder\etc\apps\$appName\default"

if(Test-Path "$appPath")
{
    Write-Host "Splunk app directory already exists. Removing existing configs"
	
	# Remove-Item recursion does not work correctly - http://technet.microsoft.com/library/hh849765.aspx (-Recurse section)
    # Remove files first then directories (leaf -> root) so we don't get the recursion confirm popup
    Get-ChildItem $appPath -Recurse | Where { ! $_.PSIsContainer } | Remove-Item -Force
    Get-ChildItem $appPath -Recurse | Where { $_.PSIsContainer } | Sort @{ Expression = { $_.FullName.length } } -Descending | Remove-Item -Force
}
else
{
    Write-Host "Creating splunk app directory"
    New-Item "$appPath" -type Directory
}

# Create forwarder config

Write-Host "Creating splunk forwarder config"

$str = "[monitor://$file]`r`ndisabled = false`r`nfollowTail = 0`r`nsourcetype = $appName`r`nindex = $index"
New-Item "$appPath\inputs.conf" -type File -value $str

# Restart forwarder service

Write-Host "Restarting splunk forwarder"
Restart-Service "SplunkForwarder"