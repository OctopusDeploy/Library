function TriggerMultitenantDeployment {
		### Steps: 
		###    1. find most recent release of the Multi-tenanted project by project name if Release Number (2) parameter is empty
		###    2. locate all the tenants for specified tag
		###    3. for each tenant create a new deployment for the found release with the parameters

    param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$apiUrl,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$apiKey,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$projectName,
        [Parameter(Mandatory = $false)]
        [string]$releaseNumber = '',
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$environmentName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$tenantsTag
    )
			

		$errors=0
		$headers = @{"X-Octopus-ApiKey"=$apiKey}
		
		$initiator = "#{Octopus.Deployment.CreatedBy.Username}"

		Write-Host "### TriggerMultiTenantedDeployment parameters:"
		Write-Host "###`tAPI URL: [$($apiUrl)]"
		if($debug) {
			Write-Host "###`tAPI Key: [$($apiKey)]"
		}
		Write-Host "###`tProject Name: [$($projectName)]"
		Write-Host "###`tRelease Number: [$($releaseNumber)]"
		Write-Host "###`tEnvironment: [$($environmentName)]"
		Write-Host "###`tTenants Tag Name: [$($tenantsTag)]"
		Write-Host "###`tInitiator: [$($initiator)]"

		try {
			if (-Not ($tenantsTag -match '\w+/\w+'))
			{
				Write-Error "### Tenants Tag Name must be in format 'TenantTagSet/TenantTag'"
				$errors=1
			}
			$projects = Invoke-RestMethod -Method GET -Uri $apiUrl/projects/all -Headers $headers 
			$project = $projects | where Name -eq $projectName
			if (-Not $project) {
				Write-Error "### Could not find project with name [$($projectName)]."
				$errors=1
			}
            $projectUrl="$($apiUrl)/projects/$($project.Id)/releases"
			$releases = Invoke-RestMethod -Method GET -Uri $projectUrl -Headers $headers | select -expand Items
			$mostRecentRelease = $releases | Sort-Object -Descending -Property { [int]($_.Version -replace "\.") } | Select -First 1
			$release = $releases | where Version -eq $releaseNumber | Select -First 1
			if (-Not ($release)) {
				$release=$mostRecentRelease
				Write-Host "### Selected most recent release [$($release.Version)]."
			}
			if(-Not $release) {
				if($releaseNumber) {
					Write-Error "### Could not find release [$($releaseNumber)]for project with name [$($projectName)]."
				} else {
					Write-Error "### Could not find any releases for project with name [$($projectName)]."
				}
				$errors=1
			}
			$environments = Invoke-RestMethod -Method GET -Uri $apiUrl/environments/all -Headers $headers
			$environment =  $environments | where Name -eq $environmentName
			if(-Not $environment){
				Write-Error "### Could not find environment [$($environmentName)] for project with name [$($projectName)]."
				$errors=1
			}
			$tenants = Invoke-RestMethod -Method GET -Uri $apiUrl/tenants/all -Headers $headers 
			$selectedTenants = $tenants | where TenantTags -Contains $tenantsTag
			if(-Not $selectedTenants){
				Write-Error "### Could not find any tenants with tag [$($tenantsTag)]."
				$errors=1
			}
			if($errors)
			{
				Fail-Step "### Encoutered an error. See log for more details. Interrupting the task."
			}

			if ($debug){
				Write-Host "##Project##: " $project
				Write-Host "##Project.Id##: " $projectId
				Write-Host "##LifeCycleId##: " $lifeCycleId
				Write-Host "##Release##: " $release
				Write-Host "##ReleaseId##: " $release.Id
				Write-Host "##ChannelId##: " $release.channelId
				Write-Host "##TenantsTag##: " $tag.Id $tag.CanonicalTagName
				Write-Host "##SelectedTenants##: " $selectedTenants.Count
			}

			foreach($tenant in $selectedTenants) {
				$deploymentJson = "{`"ProjectId`":`"$($projectId)`",`"ReleaseId`":`"$($release.Id)`",`"EnvironmentId`":`"$($environment.Id)`",`"ChannelId`":`"$($release.channelId)`",`"TenantId`":`"$($tenant.Id)`",`"Comments`":`"Initiated by $($initiator)`"}"
			
				if($debug) { Write-Host "##DeploymentJson##: $($deploymentJson)" }
				
				$deployment = Invoke-RestMethod -Method POST -Uri $apiUrl/deployments -Headers $headers -Body $deploymentJson
				Write-Host "### Created new deployment for $($tenant.Name): [$($deployment)]."
				Write-Host "### Deployment for release [$($project.Name) $($release.Version)], tenant [$($tenant.Name)] in [$($environmentName)] environment was created and scheduled successfuly."
			}
			exit
		} Catch {
			Write-Error "### Failed to complete deployment for " $projectName "to" $environmentName "for" $tenantsTag
			throw $_
		}
}


	TriggerMultitenantDeployment -apiUrl $OctopusAPIurl -apiKey $OctopusAPIkey -projectName $MultiTenantProjectName -environmentName $EnvironmentName -releaseNumber $ReleaseNumber -tenantsTag $TenantsTag
