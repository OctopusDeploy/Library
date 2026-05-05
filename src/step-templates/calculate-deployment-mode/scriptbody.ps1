$currentReleaseNumber = $OctopusParameters["Octopus.Release.Number"]
$previousReleaseNumber = $OctopusParameters["Octopus.Release.CurrentForEnvironment.Number"]
$lastAttemptedReleaseNumber = $OctopusParameters["Octopus.Release.PreviousForEnvironment.Number"]
$stepName = $OctopusParameters["Octopus.Action.StepName"]
$triggerName = $OctopusParameters["Octopus.Deployment.Trigger.Name"]

Write-Host "The current release number is $currentReleaseNumber"
Write-Host "The last succesful release to this environment was $previousReleaseNumber"
Write-Host "The last release that was attempted on this environment was $lastAttemptedReleaseNumber"
Write-Host "The deployment name is $deploymentName"

if ($previousReleaseNumber -like "*-*")
{
	$previousReleaseNumber = $previousReleaseNumber.SubString(0, $previousReleaseNumber.IndexOf("-"))
}

if ($currentReleaseNumber -like "*-*")
{
	$currentReleaseNumber = $currentReleaseNumber.SubString(0, $currentReleaseNumber.IndexOf("-"))
}

if ($lastAttemptedReleaseNumber -like "*-*")
{
	$lastAttemptedReleaseNumber = $lastAttemptedReleaseNumber.SubString(0, $lastAttemptedReleaseNumber.IndexOf("-"))
}

Write-Host "The non-pre release tag previous version for the environment was $previousReleaseNumber"
Write-Host "The non-pre release tag current release number is $currentReleaseNumber"
Write-Host "The non-pre release tag of the last attempted version for the environment was $lastAttemptedReleaseNumber"

$currentVersion = [System.Version]$currentReleaseNumber
$previousVersion = [System.Version]$previousReleaseNumber
$lastAttemptedVersion = [System.Version]$lastAttemptedReleaseNumber

$differentVersions = $false
$versionToCompare = $previousVersion
if ($currentVersion -gt $previousVersion)
{
	Write-Host "The current release number $currentReleaseNumber is greater than the previous successful release number $previousReleaseNumber."
	if ($currentVersion -lt $lastAttemptedVersion)
    {
    	Write-Host "The current release number $currentReleaseNumber is less than the last attempted release number $lastAttemptedReleaseNumber.  Setting deployment mode to rollback."
	    $deploymentMode = "Rollback"
        $versionToCompare = $lastAttemptedVersion
    }
    else
    {
    	Write-Host "The current release number $curentReleaseNumber is greater than the last attempted release number $lastAttemptedReleaseNumber.  Setting deployment mode to deploy."
        $deploymentMode = "Deploy"
    }
}
elseif ($currentVersion -lt $previousVersion)
{
	Write-Host "The current release number $currentReleaseNumber is less than the previous successful release number $previousReleaseNumber.  Setting deployment mode to rollback."
    $deploymentMode = "Rollback"
    $differentVersions = $true
}
elseif ($currentVersion -lt $lastAttemptedVersion)
{
	Write-Host "The current release number $currentReleaseNumber is less than the last attempted release number $lastAttemptedReleaseNumber.  Setting the deployment mode to rollback."
    $deploymentMode = "Rollback"
    $differentVersions = $true
    $versionToCompare = $lastAttemptedVersion
}
else
{
	Write-Host "The current release number $currentReleaseNumber matches the previous release number $previousReleaseNumber.  Setting deployment mode to redeployment."
    $deploymentMode = "Redeploy"
}

$differenceKind = "Identical"
if ($differentVersions)
{
	if ($currentVersion.Major -ne $versionToCompare.Major)
    {
    	Write-Host "$currentReleaseNumber is a major version change from $versionToCompare"
    	$differenceKind = "Major"
    }
    elseif ($currentVersion.Minor -ne $versionToCompare.Minor)
    {
    	Write-Host "$currentReleaseNumber is a minor version change from $versionToCompare"
    	$differenceKind = "Minor"
    }
    elseif ($currentVersion.Build -ne $versionToCompare.Build)
    {
    	Write-Host "$currentReleaseNumber is a build version change from $versionToCompare"
    	$differenceKind = "Build"
    }
    elseif ($currentVersion.Revision -ne $versionToCompare.Revision)
    {
    	Write-Host "$currentReleaseNumber is a revision version change from $versionToCompare"
    	$differenceKind = "Revision"
    }
}

$trigger = $false
if ([string]::IsNullOrWhiteSpace($triggerName) -eq $false)
{
	Write-Host "This task was created by trigger $triggerName."
    $trigger = $true
}

Set-OctopusVariable -Name "DeploymentMode" -Value $deploymentMode
Set-OctopusVariable -Name "VersionChange" -Value $differenceKind
Set-OctopusVariable -Name "Trigger" -Value $trigger

Write-Highlight @"
Output Variables Created:
   	- Octopus.Action[$($stepName)].Output.DeploymentMode - Set to '$deploymentMode'
    - Octopus.Action[$($stepName)].Output.VersionChange - Set to '$differenceKind'
    - Octopus.Action[$($stepName)].Output.Trigger - Set to '$trigger'

Deployment Mode Run Conditions Output Variables:
   	- Octopus.Action[$($stepName)].Output.RunOnRollback
    - Octopus.Action[$($stepName)].Output.RunOnDeploy
    - Octopus.Action[$($stepName)].Output.RunOnRedeploy
    - Octopus.Action[$($stepName)].Output.RunOnDeployOrRollback
    - Octopus.Action[$($stepName)].Output.RunOnDeployOrRedeploy
    - Octopus.Action[$($stepName)].Output.RunOnRollbackOrRedeploy

Version Change Run Conditions Output Variables:
   	- Octopus.Action[$($stepName)].Output.RunOnMajorVersionChange
    - Octopus.Action[$($stepName)].Output.RunOnMinorVersionChange
    - Octopus.Action[$($stepName)].Output.RunOnMajorOrMinorVersionChange
    - Octopus.Action[$($stepName)].Output.RunOnBuildVersionChange
    - Octopus.Action[$($stepName)].Output.RunOnRevisionVersionChange
  
Variable run conditions are always evaluated, even if there is an error.  Use the following examples to control when your step runs.  Replace RunOnDeploy from below examples with one of the variables from above.  
- Always Run: `#{Octopus.Action[$stepName].Output.RunOnDeploy}`  
- Success: Only run when previous steps succeeds `##{unless Octopus.Deployment.Error}#{Octopus.Action[$stepName].Output.RunOnDeploy}##{/unless}`
- Failure: Only run when previous steps fail `##{if Octopus.Deployment.Error}#{Octopus.Action[$stepName].Output.RunOnDeploy}##{/if}`

"@

$runOnRollback = "#{if Octopus.Action[$($stepName)].Output.DeploymentMode == ""Rollback""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnRollback' so you can use it as a run condition"
Write-Verbose $runOnRollback
Set-OctopusVariable -Name "RunOnRollback" -Value $runOnRollback

$runOnDeploy = "#{if Octopus.Action[$($stepName)].Output.DeploymentMode == ""Deploy""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnDeploy' so you can use it as a run condition"
Write-Verbose $runOnDeploy
Set-OctopusVariable -Name "RunOnDeploy" -Value $runOnDeploy

$runOnRedeploy = "#{if Octopus.Action[$($stepName)].Output.DeploymentMode == ""Redeploy""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnRedeploy' so you can use it as a run condition"
Write-Verbose $runOnRedeploy
Set-OctopusVariable -Name "RunOnRedeploy" -Value $runOnRedeploy

$runOnDeployOrRollback = "#{if Octopus.Action[$($stepName)].Output.DeploymentMode != ""Redeploy""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnDeployOrRollback' so you can use it as a run condition"
Write-Verbose $runOnDeployOrRollback
Set-OctopusVariable -Name "RunOnDeployOrRollback" -Value $runOnDeployOrRollback

$runOnDeployOrRedeploy = "#{if Octopus.Action[$($stepName)].Output.DeploymentMode != ""Rollback""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnDeployOrRedeploy' so you can use it as a run condition"
Write-Verbose $runOnDeployOrRedeploy
Set-OctopusVariable -Name "RunOnDeployOrRedeploy" -Value $runOnDeployOrRedeploy

$runOnRedeployOrRollback = "#{if Octopus.Action[$($stepName)].Output.DeploymentMode != ""Deploy""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnRedeployOrRollback' so you can use it as a run condition"
Write-Verbose $runOnRedeployOrRollback
Set-OctopusVariable -Name "RunOnRedeployOrRollback" -Value $runOnRedeployOrRollback

$runOnMajorVersionChange = "#{if Octopus.Action[$($stepName)].Output.VersionChange == ""Major""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnMajorVersionChange' so you can use it as a run condition"
Write-Verbose $runOnMajorVersionChange
Set-OctopusVariable -Name "RunOnMajorVersionChange" -Value $runOnMajorVersionChange

$runOnMinorVersionChange = "#{if Octopus.Action[$($stepName)].Output.VersionChange == ""Minor""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnMinorVersionChange' so you can use it as a run condition"
Write-Verbose $runOnMinorVersionChange
Set-OctopusVariable -Name "RunOnMinorVersionChange" -Value $runOnMinorVersionChange

$runOnMajorOrMinorVersionChange = "#{if Octopus.Action[$stepName].Output.VersionChange == ""Major""}True#{else}#{if Octopus.Action[$stepName].Output.VersionChange == ""Minor""}True#{else}False#{/if}#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnMajorOrMinorVersionChange' so you can use it as a run condition"
Write-Verbose $runOnMajorOrMinorVersionChange
Set-OctopusVariable -Name "RunOnMajorOrMinorVersionChange" -Value $runOnMajorOrMinorVersionChange

$runOnBuildVersionChange = "#{if Octopus.Action[$($stepName)].Output.VersionChange == ""Build""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnBuildVersionChange' so you can use it as a run condition"
Write-Verbose $runOnBuildVersionChange
Set-OctopusVariable -Name "RunOnBuildVersionChange" -Value $runOnBuildVersionChange

$runOnRevisionVersionChange = "#{if Octopus.Action[$($stepName)].Output.VersionChange == ""Revision""}True#{else}False#{/if}"
Write-Host "Setting the output variable 'Octopus.Action[$($stepName)].Output.RunOnRevisionVersionChange' so you can use it as a run condition"
Write-Verbose $runOnRevisionVersionChange
Set-OctopusVariable -Name "RunOnRevisionVersionChange" -Value $runOnRevisionVersionChange