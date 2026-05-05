#region Verify variables

#No need to verify PerformRollingDeploy as this is a checkbox and will always have a boolean value. Report value back for logging.
Try
{
  $performRollingDeploy = [System.Convert]::ToBoolean($OctopusParameters['DRDWSPerformRollingDeploy'])
  Write-Host ('Perform Rolling Deploy: ' + $performRollingDeploy)
}
Catch
{
  Throw "Cannot convert Perform Rolling Deploy: '" + $OctopusParameters['DRDWSPerformRollingDeploy'] + "' to boolean value. Try having the expression or variable evaluate to 'True' or 'False'."
}

#Verify ServerPercentageToDeploy can be converted to integer.
If ([string]::IsNullOrEmpty($OctopusParameters['DRDWSServerPercentageToDeploy']))
{
  Throw 'Server percentage to deploy cannot be null.'
}

[int]$serverPercentageToDeploy = 0
[bool]$result = [int]::TryParse($OctopusParameters['DRDWSServerPercentageToDeploy'], [ref]$serverPercentageToDeploy)

If ($result)
{
  Write-Host ('Server percentage to deploy: ' + $serverPercentageToDeploy + '%')
  $serverPercentToDisconnect = $serverPercentageToDeploy / 100
}
Else
{
  Throw "Cannot convert Server percentage to deploy: '" + $OctopusParameters['DRDWSServerPercentageToDeploy'] + "' to integer."
}

#Verify ServerRole is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['DRDWSServerRole']))
{
  Throw 'Server Role for Rolling Deploy cannot be null.'
}
$role = $OctopusParameters['DRDWSServerRole']
Write-Host ('Server Role for Rolling Deploy: ' + $role)

#endregion


#region Process

$serverCountToDeployTo = 9999

If ($performRollingDeploy)
{
  $servers = $OctopusParameters['Octopus.Environment.MachinesInRole[' + $role + ']']
  $totalMachines = If ([string]::IsNullOrEmpty($servers)) { 0 } else { ($servers.Split(',')).Count }
  $serverCountToDeployTo = [math]::Round(($totalMachines * $serverPercentToDisconnect))

  Write-Host ('Total machines: ' + $totalMachines)

  If ($serverCountToDeployTo -eq 0)
  {
    $serverCountToDeployTo++
  }
}

Write-Host ('Window Size: ' + $serverCountToDeployTo)

#To use this value, set Window size value to: #{Octopus.Action[Determine Rolling Deploy Window Size].Output.WindowSize}
Set-OctopusVariable -name "WindowSize" -value $serverCountToDeployTo

#endregion
