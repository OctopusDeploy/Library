Import-Module WebAdministration

$websites = Get-ChildItem IIS:\Sites
$continue = $true

#Verify sleepSeconds can be converted to integer.
$sleepSecondsString = 4

If ($OctopusParameters['wfitdSleepSeconds'])
{
  $sleepSecondsString = $OctopusParameters['wfitdSleepSeconds']
}

[int]$sleepSeconds = 0
[bool]$result = [int]::TryParse($sleepSecondsString, [ref]$sleepSeconds)

If ($result)
{
  Write-Host ('Sleep Seconds: ' + $sleepSeconds)
}
Else
{
  Throw "Cannot convert Sleep Seconds: '" + $sleepSecondsString + "' to integer."
}

#Verify totalWaitMinutes can be converted to integer.
$totalWaitMinutesString = 5

If ($OctopusParameters['wfitdTotalWaitMinutes'])
{
  $totalWaitMinutesString = $OctopusParameters['wfitdTotalWaitMinutes']
}

[int]$totalWaitMinutes = 0
[bool]$result = [int]::TryParse($totalWaitMinutesString, [ref]$totalWaitMinutes)

If ($result)
{
  Write-Host ('Total Wait Minutes: ' + $totalWaitMinutes)
}
Else
{
  Throw "Cannot convert Total Wait Minutes: '" + $totalWaitMinutesString + "' to integer."
}

Write-Host '***********************************************'

$stopWatch = [system.diagnostics.stopwatch]::StartNew()
While ($continue)
{
  $connectionsExist = $false
  
  Foreach ($website in $websites)
  {
    $connections = (Get-Counter ('\\' + $env:COMPUTERNAME  + '\web service(' + $website.name + ')\Current Connections')).CounterSamples.CookedValue
    Write-Host ($website.Name + ' - ' + $connections + ' connection(s).')
    If ($connections -gt 0)
    {
      $connectionsExist = $true
    }
  }
  
  If ($connectionsExist)
  {
    Start-Sleep -Seconds $sleepSeconds
    
    If ($stopWatch.Elapsed.Minutes -ge $totalWaitMinutes)
    {
      $continue = $false
    }
  }
  Else
  {
    $continue = $false
  }
  
  Write-Host ('Elapsed seconds: ' + $stopWatch.Elapsed.TotalSeconds)
  Write-Host '==============================================='
}

$stopWatch.Stop()
