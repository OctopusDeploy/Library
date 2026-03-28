$manIntStepName = $OctopusParameters["URE.ManualInterventionStepName"]

Write-Host "Created by: "$OctopusParameters["Octopus.Deployment.CreatedBy.Username"]
Write-Host "Approved by: "$OctopusParameters["Octopus.Action[$manIntStepName].Output.Manual.ResponsibleUser.Username"]

If ($OctopusParameters["URE.PreventDeployerFromApproving"] -eq $true) {
  $deploymentCreatedByUsername = $OctopusParameters["Octopus.Deployment.CreatedBy.Username"]
}
$approvedByUsername = $OctopusParameters["Octopus.Action[$manIntStepName].Output.Manual.ResponsibleUser.Username"]

If ($approvedByUsername -eq $deploymentCreatedByUsername) {
  Write-Warning "The same user may not be used to both start the deployment and approve the deployment."
  Write-Warning "Please retry the deployment with a different approver for the $manIntStepName step."
  throw "Terminating deployment..."
}
Else {
  $excludedUserList = $OctopusParameters["URE.ExcludedUsers"].Split([System.Environment]::NewLine)
  If ($excludedUserList -contains $approvedByUsername) {
  Write-Warning "The user $approvedByUsername may not approve this deployment."
  Write-Warning "Please retry the deployment with a different approver for the $manIntStepName step."
  throw "Terminating deployment..."
  }
}

If (($OctopusParameters["URE.PreventDeployerFromApproving"] -ne $true) -and (!$excludedUserList)) {
  Write-Host ">>>PreventDeployerFromApproving set to FALSE" 
  Write-Host ">>>ExcludedUsers contain no value(s)"
}
Write-Host "Check complete"
Write-Host "Continuing..."
  