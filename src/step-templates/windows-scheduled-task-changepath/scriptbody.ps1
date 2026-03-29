$taskName   = $OctopusParameters['TaskName']
$taskFolder = $OctopusParameters['TaskFolder']
$taskExe    = $OctopusParameters['TaskExe']
$userName   = $OctopusParameters['TaskUserName']
$password   = $OctopusParameters['TaskPassword']

$taskPath = Join-Path $taskFolder $taskExe
Write-Output "Changing execution path of $taskName to $taskPath"

#Check if 2008 Server
if ((Get-WmiObject Win32_OperatingSystem).Name.Contains("2008"))
{
    $userName = "`"$userName`""
    schtasks /Change /RU $userName /RP $password /TR $taskPath /TN $taskName
}
else
{
    $action = New-ScheduledTaskAction -Execute $taskPath
    Set-ScheduledTask -TaskName $taskName -Action $action -User $userName -Password $password;
}