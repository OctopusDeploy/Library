[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Supplied Octopus Parameters
$parentReleaseId = $OctopusParameters["Octopus.Release.Id"]
$parentChannelId = $OctopusParameters["Octopus.Release.Channel.Id"]
$destinationSpaceId = $OctopusParameters["Octopus.Space.Id"]
$specificMachines = $OctopusParameters["Octopus.Deployment.SpecificMachines"]
$excludeMachines = $OctopusParameters["Octopus.Deployment.ExcludedMachines"]
$deploymentMachines = $OctopusParameters["Octopus.Deployment.Machines"]
$parentDeploymentTaskId = $OctopusParameters["Octopus.Task.Id"]
$parentProjectName = $OctopusParameters["Octopus.Project.Name"]
$parentReleaseNumber = $OctopusParameters["Octopus.Release.Number"]
$parentEnvironmentName = $OctopusParameters["Octopus.Environment.Name"]
$parentEnvironmentId = $OctopusParameters["Octopus.Environment.Id"]
$parentSpaceId = $OctopusParameters["Octopus.Space.Id"]

# User Parameters
$octopusApiKey = $OctopusParameters["ChildProject.Api.Key"]
$projectName = $OctopusParameters["ChildProject.Project.Name"]
$channelName = $OctopusParameters["ChildProject.Channel.Name"]
$releaseNumber = $OctopusParameters["ChildProject.Release.Number"]
$environmentName = $OctopusParameters["ChildProject.Destination.EnvironmentName"]
$sourceEnvironmentName = $OctopusParameters["ChildProject.SourceEnvironment.Name"]
$formValues = $OctopusParameters["ChildProject.Prompted.Variables"]
$destinationSpaceName = $OctopusParameters["ChildProject.Space.Name"]
$whatIfValue = $OctopusParameters["ChildProject.WhatIf.Value"]
$waitForFinishValue = $OctopusParameters["ChildProject.WaitForFinish.Value"]
$enableEnhancedLoggingValue = $OctopusParameters['ChildProject.EnableEnhancedLogging.Value']
$deploymentCancelInSeconds = $OctopusParameters["ChildProject.CancelDeployment.Seconds"]
$ignoreSpecificMachineMismatchValue = $OctopusParameters["ChildProject.Deployment.IgnoreSpecificMachineMismatch"]
$autoapproveChildManualInterventionsValue = $OctopusParameters["ChildProject.ManualInterventions.UseApprovalsFromParent"]
$saveReleaseNotesAsArtifactValue = $OctopusParameters["ChildProject.ReleaseNotes.SaveAsArtifact"]
$futureDeploymentDate = $OctopusParameters["ChildProject.Deployment.FutureTime"]
$errorHandleForNoRelease = $OctopusParameters["ChildProject.Release.NotFoundError"]
$approvalEnvironmentName = $OctopusParameters["ChildProject.ManualIntervention.EnvironmentToUse"]
$approvalTenantName = $OctopusParameters["ChildProject.ManualIntervention.Tenant.Name"]
$refreshVariableSnapShot = $OctopusParameters["ChildProject.RefreshVariableSnapShots.Option"]
$deploymentMode = $OctopusParameters["ChildProject.DeploymentMode.Value"]
$targetMachines = $OctopusParameters["ChildProject.Target.MachineNames"]
$deploymentTenantName = $OctopusParameters["ChildProject.Tenant.Name"]
$defaultUrl = $OctopusParameters["ChildProject.Web.ServerUrl"]

$cachedResults = @{}

function Write-OctopusVerbose
{
    param($message)
    
    Write-Verbose $message  
}

function Write-OctopusInformation
{
    param($message)
    
    Write-Host $message  
}

function Write-OctopusSuccess
{
    param($message)

    Write-Highlight $message 
}

function Write-OctopusWarning
{
    param($message)

    Write-Warning "$message" 
}

function Write-OctopusCritical
{
    param ($message)

    Write-Error "$message" 
}

function Test-RequiredValues
{
	param (
    	$variableToCheck,
        $variableName
    )
    
    if ([string]::IsNullOrWhiteSpace($variableToCheck) -eq $true)
    {
    	Write-OctopusCritical "$variableName is required."
        return $false
    }
    
    return $true
}

function Invoke-OctopusApi
{
    param
    (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $method,
        $item,
        $ignoreCache     
    )

    if ([string]::IsNullOrWhiteSpace($SpaceId))
    {
        $url = "$OctopusUrl/api/$EndPoint"
    }
    else
    {
        $url = "$OctopusUrl/api/$spaceId/$EndPoint"    
    }  

    try
    {        
        if ($null -ne $item)
        {
            $body = $item | ConvertTo-Json -Depth 10
            Write-OctopusVerbose $body

            Write-OctopusInformation "Invoking $method $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8' 
        }

        if (($null -eq $ignoreCache -or $ignoreCache -eq $false) -and $method.ToUpper().Trim() -eq "GET")
        {
            Write-OctopusVerbose "Checking to see if $url is already in the cache"
            if ($cachedResults.ContainsKey($url) -eq $true)
            {
                Write-OctopusVerbose "$url is already in the cache, returning the result"
                return $cachedResults[$url]
            }
        }
        else
        {
            Write-OctopusVerbose "Ignoring cache."    
        }

        Write-OctopusVerbose "No data to post or put, calling bog standard invoke-restmethod for $url"
        $result = Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'

        if ($cachedResults.ContainsKey($url) -eq $true)
        {
            $cachedResults.Remove($url)
        }
        Write-OctopusVerbose "Adding $url to the cache"
        $cachedResults.add($url, $result)

        return $result

               
    }
    catch
    {
        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-OctopusCritical "Unauthorized error returned from $url, please verify API key and try again"
            }
            elseif ($_.Exception.Response.statusCode -eq 403)
            {
                Write-OctopusCritical "Forbidden error returned from $url, please verify API key and try again"
            }
            else
            {                
                Write-OctopusVerbose -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )"
            }            
        }
        else
        {
            Write-OctopusVerbose $_.Exception
        }
    }

    Throw "There was an error calling the Octopus API please check the log for more details"
}

function Get-ListFromOctopusApi
{
    param (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $propertyName
    )

    $rawItemList = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint $endPoint -spaceId $spaceId -apiKey $octopusApiKey -method "GET"

    $returnList = @($rawItemList.$propertyName)

    Write-OctopusVerbose "The endpoint $endPoint returned a list with $($returnList.Count) items"

    return ,$returnList
}

function Get-FilteredOctopusItem
{
    param(
        $itemList,
        $itemName
    )

    if ($itemList.Count -eq 0)
    {
        Write-OctopusCritical "Unable to find $itemName.  Exiting with an exit code of 1."
        Exit 1
    }  

    $item = $itemList | Where-Object { $_.Name.ToLower().Trim() -eq $itemName.ToLower().Trim() }      

    if ($null -eq $item)
    {
        Write-OctopusCritical "Unable to find $itemName.  Exiting with an exit code of 1."
        exit 1
    }

    return $item
}

function Test-PhaseContainsEnvironmentId
{
    param (
        $phase,
        $environmentId
    )

    Write-OctopusVerbose "Checking to see if $($phase.Name) automatic deployment environments $($phase.AutomaticDeploymentTargets) contains $environmentId"
    if ($phase.AutomaticDeploymentTargets -contains $environmentId)
    {
        Write-OctopusVerbose "It does, returning true"
        return $true
    } 
    
    Write-OctopusVerbose "Checking to see if $($phase.Name) optional deployment environments $($phase.OptionalDeploymentTargets) contains $environmentId"
    if ($phase.OptionalDeploymentTargets -contains $environmentId)
    {
        Write-OctopusVerbose "It does, returning true"
        return $true
    }

    Write-OctopusVerbose "The phase does not contain the environment returning false"
    return $false
}

function Get-OctopusItemByName
{
    param(
        $itemName,
        $itemType,
        $endpoint,
        $defaultValue,
        $spaceId,
        $defaultUrl,
        $octopusApiKey
    )

    if ([string]::IsNullOrWhiteSpace($itemName) -or $itemName -like "#{Octopus*")
    {
        Write-OctopusVerbose "The item name passed in was $itemName, returning the default value for $itemType"
        return $defaultValue
    }

    Write-OctopusInformation "Attempting to find $itemType with the name of $itemName"
    
    $itemList = Get-ListFromOctopusApi -octopusUrl $defaultUrl -endPoint "$($endPoint)?partialName=$([uri]::EscapeDataString($itemName))&skip=0&take=100" -spaceId $spaceId -apiKey $octopusApiKey -method "GET" -propertyName "Items"   
    $item = Get-FilteredOctopusItem -itemList $itemList -itemName $itemName

    Write-OctopusInformation "Successfully found $itemName with id of $($item.Id)"

    return $item
}

function Get-OctopusItemById
{
    param(
        $itemId,
        $itemType,
        $endpoint,
        $defaultValue,
        $spaceId,
        $defaultUrl,
        $octopusApiKey
    )

    if ([string]::IsNullOrWhiteSpace($itemId))
    {
        return $defaultValue
    }

    Write-OctopusInformation "Attempting to find $itemType with the id of $itemId"
    
    $item = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "$endPoint/$itemId" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"        

    if ($null -eq $item)
    {
        Write-OctopusCritical "Unable to find $itemType with the id of $itemId"
        exit 1
    }
    else 
    {
        Write-OctopusInformation "Successfully found $itemId with name of $($item.Name)"    
    }
    
    return $item
}

function Get-OctopusSpaceIdByName
{
	param(
    	$spaceName,
        $spaceId,
        $defaultUrl,
        $octopusApiKey    
    )
    
    if ([string]::IsNullOrWhiteSpace($spaceName))
    {
    	return $spaceId
    }

    $space = Get-OctopusItemByName -itemName $spaceName -itemType "Space" -endpoint "spaces" -defaultValue $spaceId -spaceId $null -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey
    
    return $space.Id
}

function Get-OctopusProjectByName
{
    param (
        $projectName,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    return Get-OctopusItemByName -itemName $projectName -itemType "Project" -endpoint "projects" -defaultValue $null -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey    
}

function Get-OctopusEnvironmentByName
{
    param (
        $environmentName,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    return Get-OctopusItemByName -itemName $environmentName -itemType "Environment" -endpoint "environments" -defaultValue $null -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey    
}

function Get-OctopusTenantByName
{
    param (
        $tenantName,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    return Get-OctopusItemByName -itemName $tenantName -itemType "Tenant" -endpoint "tenants" -defaultValue $null -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey    
}

function Get-OctopusApprovalTenant
{
    param (
        $tenantToDeploy,
        $approvalTenantName,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    Write-OctopusInformation "Checking to see if there is an approval tenant to consider"

    if ($null -eq $tenantToDeploy)
    {
        Write-OctopusInformation "Not doing tenant deployments, skipping this check"    
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($approvalTenantName) -eq $true -or $approvalTenantName -eq "#{Octopus.Deployment.Tenant.Name}")
    {
        Write-OctopusInformation "No approval tenant was provided, returning $($tenantToDeploy.Id)"
        return $tenantToDeploy
    }

    if ($approvalTenantName.ToLower().Trim() -eq $tenantToDeploy.Name.ToLower().Trim())
    {
        Write-OctopusInformation "The approval tenant name matches the deployment tenant name, using the current tenant"
        return $tenantToDeploy
    }

    return Get-OctopusTenantByName -tenantName $approvalTenantName -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey
}

function Get-OctopusChannel
{
    param (
        $channelName,
        $project,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    Write-OctopusInformation "Attempting to find the channel information for project $projectName matching the channel name $channelName"
    $channelList = Get-ListFromOctopusApi -octopusUrl $defaultUrl -endPoint "projects/$($project.Id)/channels?skip=0&take=1000" -spaceId $spaceId -apiKey $octopusApiKey -method "GET" -propertyName "Items"
    $channelToUse = $null
    foreach ($channel in $channelList)
    {
        if ([string]::IsNullOrWhiteSpace($channelName) -eq $true -and $channel.IsDefault -eq $true)
        {
            Write-OctopusVerbose "The channel name specified is null or empty and the current channel $($channel.Name) is the default, using that"
            $channelToUse = $channel
            break
        }

        if ([string]::IsNullOrWhiteSpace($channelName) -eq $false -and $channel.Name.Trim().ToLowerInvariant() -eq $channelName.Trim().ToLowerInvariant())
        {
            Write-OctopusVerbose "The channel name specified $channelName matches the the current channel $($channel.Name) using that"
            $channelToUse = $channel
            break
        }
    }

    if ($null -eq $channelToUse)
    {
        Write-OctopusCritical "Unable to find a channel to use.  Exiting with an exit code of 1."
        exit 1
    }

    return $channelToUse
}

function Get-OctopusLifecyclePhases
{
    param (
        $channel,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $project
    )

    Write-OctopusInformation "Attempting to find the lifecycle information $($channel.Name)"
    if ($null -eq $channel.LifecycleId)
    {
        return Get-ListFromOctopusApi -octopusUrl $defaultUrl -endPoint "lifecycles/$($project.LifecycleId)/preview" -spaceId $spaceId -apiKey $octopusApiKey -method "GET" -propertyName "Phases"
    }
    else
    {
        return Get-ListFromOctopusApi -octopusUrl $defaultUrl -endPoint "lifecycles/$($channel.LifecycleId)/preview" -spaceId $spaceId -apiKey $octopusApiKey -method "GET" -propertyName "Phases"
    }
}

function Get-SourceDestinationEnvironmentInformation
{
    param (
        $phaseList,
        $targetEnvironment,
        $sourceEnvironment,
        $isPromotionMode,
        $isAlwaysLatestMode
    )

    Write-OctopusVerbose "Attempting to pull the environment ids from the source and destination phases"

    $destTargetEnvironmentInfo = @{        
        TargetEnvironment = $targetEnvironment
        SourceEnvironmentList = @()
        FirstLifecyclePhase = $false
        HasRequiredPhase = $false
    }

    if ($isPromotionMode -eq $false)
    {
        if ($isAlwaysLatestMode -eq $true)
        {
            Write-OctopusInformation "Currently running in AlwaysLatest mode, setting the source environment to the target environment."
        }
        else
        {
            Write-OctopusInformation "Currently running in redeploy mode, setting the source environment to the target environment."

        }
        $destTargetEnvironmentInfo.SourceEnvironmentList = $targetEnvironment.Id

        return $destTargetEnvironmentInfo
    }

    $indexOfTargetEnvironment = $null
    for ($i = 0; $i -lt $phaseList.Length; $i++)
    {
        Write-OctopusInformation "Checking to see if lifecycle phase $($phaseList[$i].Name) contains the target environment id $($targetEnvironment.Id)"

        if (Test-PhaseContainsEnvironmentId -phase $phaseList[$i] -environmentId $targetEnvironment.Id)    
        {            
            Write-OctopusVerbose "The phase $($phaseList[$i].Name) has the environment $($targetEnvironment.Name)."
            $indexOfTargetEnvironment = $i
            break
        }
    }

    if ($null -eq $indexOfTargetEnvironment)
    {
        Write-OctopusCritical "Unable to find the target phase in this lifecycle attached to this channel.  Exiting with exit code of 1"
        Exit 1
    }

    if ($indexOfTargetEnvironment -eq 0)
    {
        Write-OctopusInformation "This is the first phase in the lifecycle.  The current mode is promotion.  Going to get the latest release created that matches the release number rules for the channel."
        $destTargetEnvironmentInfo.FirstLifecyclePhase = $true        
        $destTargetEnvironmentInfo.SourceEnvironmentList += $targetEnvironment.Id

        return $destTargetEnvironmentInfo
    }
    
    if ($null -ne $sourceEnvironment)
    {
        Write-OctopusInformation "The source environment $($sourceEnvironment.Name) was provided, using that as the source environment"
        $destTargetEnvironmentInfo.SourceEnvironmentList += $sourceEnvironment.Id

        return $destTargetEnvironmentInfo
    }

    Write-OctopusVerbose "Looping through all the previous phases until a required phase is found."
    $startingIndex = ($indexOfTargetEnvironment - 1)
    for($i = $startingIndex; $i -ge 0; $i--)
    {
        $previousPhase = $phaseList[$i]
        Write-OctopusInformation "Adding environments from the phase $($previousPhase.Name)"
        foreach ($environmentId in $previousPhase.AutomaticDeploymentTargets)
        {
            $destTargetEnvironmentInfo.SourceEnvironmentList += $environmentId
        }

        foreach ($environmentId in $previousPhase.OptionalDeploymentTargets)
        {
            $destTargetEnvironmentInfo.SourceEnvironmentList += $environmentId
        }

        if ($previousPhase.IsOptionalPhase -eq $false)
        {
            Write-OctopusVerbose "The phase $($previousPhase.Name) is a required phase, exiting previous phase loop"
            $destTargetEnvironmentInfo.HasRequiredPhase = $true
            break
        }
        elseif ($i -gt 0)
        {
            Write-OctopusVerbose "The phase $($previousPhase.Name) is an optional phase, continuing going to check the next phase"    
        }
        else
        {
            Write-OctopusVerbose "The phase $($previousPhase.Name) is an optional phase.  This is the last phase so I'm stopping now."    
        }
    }

    return $destTargetEnvironmentInfo             
}

function Get-ReleaseCanBeDeployedToTargetEnvironment
{
    param (
        $release,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $sourceDestinationEnvironmentInfo,
        $tenantToDeploy,
        $isPromotionMode,
        $isAlwaysLatestMode
    )

    if ($isPromotionMode -eq $false -and $isAlwaysLatestMode -eq $false)
    {
        Write-OctopusInformation "The current mode is redeploy.  Of course the release can be deployed to the target environment, no need to recheck it."
        return $true
    }

    Write-OctopusInformation "Pulling the deployment template information for release $($release.Version)"
    $releaseDeploymentTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "releases/$($release.Id)/deployments/template" -spaceId $spaceId -method GET -apiKey $octopusApiKey

    $releaseCanBeDeployedToDestination = $false    
    Write-OctopusInformation "Looping through deployment template list for $($release.Version) to see if it can be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)."
    foreach ($promoteToEnvironment in $releaseDeploymentTemplate.PromoteTo)
    {
        if ($promoteToEnvironment.Id -eq $sourceDestinationEnvironmentInfo.TargetEnvironment.Id)
        {
            Write-OctopusInformation "The environment $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name) was found in the list of environments to promote to"
            $releaseCanBeDeployedToDestination = $true
            break
        }
    }    

    if ($null -eq $tenantToDeploy -or $releaseDeploymentTemplate.TenantPromotions.Length -le 0)
    {
        return $releaseCanBeDeployedToDestination
    }

    $releaseCanBeDeployedToDestination = $false
    Write-OctopusInformation "The tenant id was supplied, looping through the tenant templates to see if it can be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)."
    foreach ($tenantPromotion in $releaseDeploymentTemplate.TenantPromotions)
    {
        if ($tenantPromotion.Id -ne $tenantToDeploy.Id)
        {
            Write-OctopusVerbose "The tenant ids $($tenantPromotion.Id) and $($tenantToDeploy.Id) don't match, moving onto the next one"
            continue
        }

        Write-OctopusVerbose "The tenant Id matches checking to see if the environment can be promoted to."
        foreach ($promoteToEnvironment in $tenantPromotion.PromoteTo)
        {
            if ($promoteToEnvironment.Id -ne $sourceDestinationEnvironmentInfo.TargetEnvironment.Id)
            {
                Write-OctopusVerbose "The environmentIds $($promoteToEnvironment.Id) and $($sourceDestinationEnvironmentInfo.TargetEnvironment.Id) don't match, moving onto the next one."
                continue
            }

            Write-OctopusInformation "The environment $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name) was found in the list of environments tenant $($tenantToDeploy.Id) can be promoted to"
            $releaseCanBeDeployedToDestination = $true
        }
    }

    return $releaseCanBeDeployedToDestination
}

function Get-DeploymentPreview
{
    param (
        $releaseToDeploy,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $targetEnvironment,
        $deploymentTenant
    )

    if ($null -eq $deploymentTenant)
    {
        Write-OctopusInformation "The deployment tenant id was not sent in, generating a preview by hitting releases/$($releaseToDeploy.Id)/deployments/preview/$($targetEnvironment.Id)?includeDisabledSteps=true"    
        return Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "releases/$($releaseToDeploy.Id)/deployments/preview/$($targetEnvironment.Id)?includeDisabledSteps=true" -apiKey $octopusApiKey -method "GET" -spaceId $spaceId
    }

    Write-OctopusInformation "The deployment tenant id was sent in, generating a preview by hitting releases/$($releaseToDeploy.Id)/deployments/previews" 
    $requestBody = @{
    		DeploymentPreviews = @(
    			@{
                	TenantId = $deploymentTenant.Id;
            		EnvironmentId = $targetEnvironment.Id
                 }
            )
    }
    return Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "releases/$($releaseToDeploy.Id)/deployments/previews" -apiKey $octopusApiKey -method "POST" -spaceId $spaceId -item $requestBody -itemIsArray $true
}

function Get-ValuesForPromptedVariables
{
    param (
        $deploymentPreview,
        $formValues
    )

    $deploymentFormValues = @{}
    if ([string]::IsNullOrWhiteSpace($formValues) -eq $true)
    {
        return $deploymentFormValues
    }   
    
    $promptedValueList = @(($formValues -Split "`n").Trim())
    Write-OctopusVerbose $promptedValueList.Length
    
    foreach($element in $deploymentPreview.Form.Elements)
    {
        $nameToSearchFor = $element.Control.Name
        $uniqueName = $element.Name
        $isRequired = $element.Control.Required
        
        $promptedVariablefound = $false
        
        Write-OctopusVerbose "Looking for the prompted variable value for $nameToSearchFor"
        foreach ($promptedValue in $promptedValueList)
        {
            $splitValue = $promptedValue -Split "::"
            Write-OctopusVerbose "Comparing $nameToSearchFor with provided prompted variable $($promptedValue[0])"
            if ($splitValue.Length -gt 1)
            {
                if ($nameToSearchFor.ToLower().Trim() -eq $splitValue[0].ToLower().Trim())
                {
                    Write-OctopusVerbose "Found the prompted variable value $nameToSearchFor"
                    $deploymentFormValues[$uniqueName] = $splitValue[1]
                    $promptedVariableFound = $true
                    break
                }
            }
        }
        
        if ($promptedVariableFound -eq $false -and $isRequired -eq $true)
        {
            Write-OctopusCritical "Unable to find a value for the required prompted variable $nameToSearchFor, exiting"
            Exit 1
        }
    }
    
    return $deploymentFormValues
}

function Test-ProjectTenantSettings
{
    param (
        $tenantToDeploy,
        $project,
        $targetEnvironment
    )

    Write-OctopusVerbose "About to check if $tenantToDeploy is not null and tenant deploy mode on the project $($project.TenantedDeploymentMode) <> Untenanted"
    if ($null -eq $tenantToDeploy)
    {
        Write-OctopusInformation "Not doing a tenanted deployment, no need to check if the project supports tenanted deployments."
        return $null
    }

    if ($project.TenantedDeploymentMode -eq "Untenanted")
    {
        Write-OctopusInformation "The project is not tenanted, but we are doing a tenanted deployment, removing the tenant from the equation"
        return $null
    }

    Write-OctopusInformation "Found the tenant $($tenantToDeploy.Name) checking to see if $($project.Name) is assigned to it."
        
    Write-OctopusVerbose "Checking to see if $($tenantToDeploy.ProjectEnvironments) has $($project.Id) as a property."
    if ($null -eq (Get-Member -InputObject $tenantToDeploy.ProjectEnvironments -Name $project.Id -MemberType Properties))
    {
        Write-OctopusSuccess "The tenant $($tenantToDeploy.Name) is not assigned to $($project.Name).  Exiting."
        Insert-EmptyOutputVariables -releaseToDeploy $null
        
        Exit 0
    }

    Write-OctopusInformation "The tenant $($tenantToDeploy.Name) is assigned to $($project.Name).  Now checking to see if it can be deployed to the target environment."
    $tenantProjectId = $project.Id
    
    Write-OctopusVerbose "Checking to see if $($tenantToDeploy.ProjectEnvironments.$tenantProjectId) has $($targetEnvironment.Id)"    
    if ($tenantToDeploy.ProjectEnvironments.$tenantProjectId -notcontains $targetEnvironment.Id)
    {
        Write-OctopusSuccess "The tenant $($tenantToDeploy.Name) is assigned to $($project.Name), but not to the environment $($targetEnvironment.Name).  Exiting."
        Insert-EmptyOutputVariables -releaseToDeploy $null
        
        Exit 0
    } 
    
    return $tenantToDeploy
}

function Test-ReleaseToDeploy
{
	param (
    	$releaseToDeploy,
        $errorHandleForNoRelease,
        $releaseNumber,        
        $sourceDestinationEnvironmentInfo, 
        $environmentList
    )
    
    if ($null -ne $releaseToDeploy)
    {
    	return
    }
        
    $errorMessage = "No releases were found in environment(s)" 

    $environmentMessage = @()
    foreach ($environmentId in $sourceDestinationEnvironmentInfo.SourceEnvironmentList)
    {
        $environment = $environmentList | Where-Object {$_.Id -eq $environmentId }

        if ($null -ne $environment)
        {
            $environmentMessage += $environment.Name
        }
    }

    $errorMessage += " $($environmentMessage -join ",")"
    
    if ([string]::IsNullOrWhitespace($releaseNumber) -eq $false)
    {
    	$errorMessage = "$errorMessage matching $releaseNumber"
    }
    
    $errorMessage = "$errorMessage that can be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)"
    
    if ($errorHandleForNoRelease -eq "Error")
    {
    	Write-OctopusCritical $errorMessage
        exit 1
    }
    
    Insert-EmptyOutputVariables -releaseToDeploy $null
    
    if ($errorHandleForNoRelease -eq "Skip")
    {
    	Write-OctopusInformation $errorMessage
        exit 0
    }
    
    Write-OctopusSuccess $errorMessage
    exit 0
}

function Get-TenantIsAssignedToPreviousEnvironments
{
    param (
        $tenantToDeploy,
        $sourceDestinationEnvironmentInfo,
        $projectId,
        $isPromotionMode
    )

    if ($null -eq $tenantToDeploy)
    {
        Write-OctopusVerbose "The tenant is null, skipping the check to see if it is assigned to the previous environment list."
        return $false
    }

    if ($isPromotionMode -eq $false)
    {
        Write-OctopusVerbose "The current mode is redeploy, the source and destination environment are the same, no need to check."
        return $true
    }

    Write-OctopusVerbose "Checking to see if $($tenantToDeploy.Name) is assigned to the previous environments."     
    Write-OctopusVerbose "Checking to see if $($tenantToDeploy.ProjectEnvironments.$projectId) is assigned to the source environments(s) $($sourceDestinationEnvironmentInfo.SourceEnvironmentList)"

    foreach ($environmentId in $tenantToDeploy.ProjectEnvironments.$projectId)
    {
        Write-OctopusVerbose "Checking to see if $environmentId appears in $($sourceDestinationEnvironmentInfo.SourceEnvironmentList)"
        if ($sourceDestinationEnvironmentInfo.SourceEnvironmentList -contains $environmentId)
        {
            Write-OctopusVerbose "Found the environment $environmentId assigned to $($tenantToDeploy.Name), attempting to find the latest release for this tenant"
            return $true
        }
    }

    Write-OctopusVerbose "The tenant is not assigned to any environment in the source environments $($sourceDestinationEnvironmentInfo.SourceEnvironmentList), pulling the latest release to the environment regardless of tenant."
    return $false
}

function Create-NewOctopusDeployment
{
	param (
    	$releaseToDeploy,
        $targetEnvironment,
        $createdDeployment,
        $project,
        $waitForFinish,
        $enableEnhancedLogging,
        $deploymentCancelInSeconds,
        $defaultUrl,
        $octopusApiKey,
        $spaceId,
        $parentDeploymentApprovers,
        $parentProjectName,
        $parentReleaseNumber, 
        $parentEnvironmentName, 
        $parentDeploymentTaskId,
        $autoapproveChildManualInterventions,
        $approvalTenant
    )
    
    Write-OctopusSuccess "Deploying $($releaseToDeploy.Version) to $($targetEnvironment.Name)"

    $createdDeploymentResponse = Invoke-OctopusApi -method "POST" -endPoint "deployments" -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -item $createdDeployment
    Write-OctopusInformation "The task id for the new deployment is $($createdDeploymentResponse.TaskId)"

    Write-OctopusSuccess "Deployment was successfully invoked, you can access the deployment [here]($defaultUrl/app#/$spaceId/projects/$($project.Slug)/deployments/releases/$($releaseToDeploy.Version)/deployments/$($createdDeploymentResponse.Id)?activeTab=taskSummary)"
    
    if ($null -ne $createdDeployment.QueueTime -and $waitForFinish -eq $true)
    {
    	Write-OctopusWarning "The option to wait for the deployment to finish was set to yes AND a future deployment date was set to a future value.  Ignoring the wait for finish option and exiting."
        return
    }
    
    if ($waitForFinish -eq $true)
    {
        Write-OctopusSuccess "Waiting until deployment has finished"
        $startTime = Get-Date
        $currentTime = Get-Date
        $dateDifference = $currentTime - $startTime
        $lastEnhancedLoggingWriteTime = [datetime]::MinValue

        $numberOfWaits = 0    

        While ($dateDifference.TotalSeconds -lt $deploymentCancelInSeconds)
        {
	        $numberOfWaits += 1
        
            Write-Host "Waiting 5 seconds to check status"
            Start-Sleep -Seconds 5
            $taskStatusResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -endPoint "tasks/$($createdDeploymentResponse.TaskId)" -method "GET" -ignoreCache $true   
            $taskStatusResponseState = $taskStatusResponse.State

            if ($taskStatusResponseState -eq "Success")
            {
                if ($enableEnhancedLogging -eq $true)
                {
                    $lastEnhancedLoggingWriteTime = Get-TaskDetails -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -taskId $createdDeploymentResponse.TaskId -lastEnhancedLoggingWriteTime $lastEnhancedLoggingWriteTime
                }
                Write-OctopusSuccess "The task has finished with a status of Success"
                exit 0            
            }
            elseif($taskStatusResponseState -eq "Failed" -or $taskStatusResponseState -eq "Canceled")
            {
                Write-OctopusSuccess "The task has finished with a status of $taskStatusResponseState status, stopping the deployment"
                exit 1            
            }
            elseif($taskStatusResponse.HasPendingInterruptions -eq $true)
            {
            	if ($autoapproveChildManualInterventions -eq $true)
                {
                	Submit-ChildProjectDeploymentForAutoApproval -createdDeployment $createdDeploymentResponse -parentDeploymentApprovers $parentDeploymentApprovers -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -parentProjectName $parentProjectName -parentReleaseNumber $parentReleaseNumber -parentEnvironmentName $parentEnvironmentName -parentDeploymentTaskId $parentDeploymentTaskId -approvalTenant $approvalTenant
                }
                else
                {
                	if ($numberOfWaits -ge 10)
                    {
                		Write-OctopusSuccess "The child project has pending manual intervention(s).  Unless you approve it, this task will time out."
                    }
                    else
                    {
                    	Write-OctopusInformation "The child project has pending manual intervention(s).  Unless you approve it, this task will time out."                        
                    }
                }
            }
            
            if ($numberOfWaits -ge 10)
            {
                if ($enableEnhancedLogging -eq $true)
                {
                    $lastEnhancedLoggingWriteTime = Get-TaskDetails -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -taskId $createdDeploymentResponse.TaskId -lastEnhancedLoggingWriteTime $lastEnhancedLoggingWriteTime
                }
                else
                {
                    Write-OctopusSuccess "The task state is currently $taskStatusResponseState"
                    $numberOfWaits = 0
                }
            }
            else
            {
                if ($enableEnhancedLogging -eq $true)
                {
                    $lastEnhancedLoggingWriteTime = Get-TaskDetails -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -taskId $createdDeploymentResponse.TaskId -lastEnhancedLoggingWriteTime $lastEnhancedLoggingWriteTime
                }
                else
                {
                    Write-OctopusInformation "The task state is currently $taskStatusResponseState"
                }
            }  

            $startTime = $taskStatusResponse.StartTime
            if ($null -eq $startTime -or [string]::IsNullOrWhiteSpace($startTime) -eq $true)
            {        
                Write-Host "The task is still queued, let's wait a bit longer"
                $startTime = Get-Date
            }
            $startTime = [DateTime]$startTime

            $currentTime = Get-Date
            $dateDifference = $currentTime - $startTime        
        }

        Write-OctopusCritical "The cancel timeout has been reached, cancelling the deployment"
        Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -method "POST" -endPoint "tasks/$($createdDeploymentResponse.TaskId)/cancel"    
        Write-OctopusInformation "Exiting with an error code of 1 because we reached the timeout"
        exit 1
    }
}

function Get-ChildDeploymentSpecificMachines
{
    param (
        $deploymentPreview,
        $deploymentMachines,
        $specificMachineDeployment
    )

    if ($specificMachineDeployment -eq $false)
    {
        Write-OctopusVerbose "Not doing specific machine deployments, returning any empty list of specific machines to deploy to"
        return @()
    }

    $filteredList = @()
    $deploymentMachineList = $deploymentMachines -split ","

    Write-OctopusInformation "Doing a specific machine deployment, comparing the machines being targeted with the machines the child project can deploy to.  The number of machines being targeted is $($deploymentMachineList.Count)"

    foreach ($deploymentMachine in $deploymentMachineList)
    {
        $deploymentMachineLowerTrim = $deploymentMachine.Trim().ToLower()           

        foreach ($step in $deploymentPreview.StepsToExecute)
        {
            foreach ($machine in $step.Machines)
            {   
                $machineLowerTrim = $machine.Id.Trim().ToLower()
                
                Write-OctopusVerbose "Comparing $deploymentMachineLowerTrim with $machineLowerTrim"
                if ($deploymentMachineLowerTrim -ne $machineLowerTrim)
                {
                    Write-OctopusVerbose "The two machine ids do not match, moving on to the next machine"
                    continue
                }

                Write-OctopusVerbose "Checking to see if $machineLowerTrim is already in the filtered list."
                if ($filteredList -notcontains $machine.Id)
                {
                    Write-OctopusVerbose "The machine is not in the list, adding it to the list."
                    $filteredList += $machine.Id
                }
            }
        }
    }

    if ($filteredList.Count -gt 0)
    {
        Write-OctopusSuccess "The machines applicable to this project are $filteredList."
    }    

    return $filteredList
}

function Test-ChildProjectDeploymentCanProceed
{
	param (
    	$releaseToDeploy,
        $specificMachineDeployment,                        
        $environmentName,
        $childDeploymentSpecificMachines,
        $project,
        $ignoreSpecificMachineMismatch,
        $deploymentMachines,
        $releaseHasAlreadyBeenDeployed,
        $isPromotionMode       
    )
    
	if ($releaseHasAlreadyBeenDeployed -eq $true -and $isPromotionMode -eq $true)
    {	     	 
    	Write-OctopusSuccess "Release $($releaseToDeploy.Version) is the most recent version deployed to $environmentName.  The deployment mode is Promote.  If you wish to redeploy this release then set the deployment mode to Redeploy.  Skipping this project."
        
        if ($specificMachineDeployment -eq $true -and $childDeploymentSpecificMachines.Length -gt 0)
        {
            Write-OctopusSuccess "$($project.Name) can deploy to $childDeploymentSpecificMachines but redeployments are not allowed."
        }
        
        Insert-EmptyOutputVariables -releaseToDeploy $releaseToDeploy

        exit 0
    }
    
    if ($childDeploymentSpecificMachines.Length -le 0 -and $specificMachineDeployment -eq $true -and $ignoreSpecificMachineMismatch -eq $false)
    {
        Write-OctopusSuccess "$($project.Name) does not deploy to $($deploymentMachines -replace ",", " OR ").  The value for ""Ignore specific machine mismatch"" is set to ""No"".  Skipping this project."
        
        Insert-EmptyOutputVariables -releaseToDeploy $releaseToDeploy
        
        Exit 0
    }

    if ($childDeploymentSpecificMachines.Length -le 0 -and $specificMachineDeployment -eq $true -and $ignoreSpecificMachineMismatch -eq $true)
    {
        Write-OctopusSuccess "You are doing a deployment for specific machines but $($project.Name) does not deploy to $($deploymentMachines -replace ",", " OR ").  You have set the value for ""Ignore specific machine mismatch"" to ""Yes"".  The child project will be deployed to, but it will do this for all machines, not any specific machines."
    }
}

function Get-ParentDeploymentApprovers
{
    param (
        $parentDeploymentTaskId,
        $spaceId,
        $defaultUrl,
        $octopusApiKey
    )
    
    $approverList = @()
    if ($null -eq $parentDeploymentTaskId)
    {
    	Write-OctopusInformation "The deployment task id to pull the approvers from is null, return an empty approver list"
    	return $approverList
    }

    Write-OctopusInformation "Getting all the events from the parent project"
    $parentDeploymentEvents = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "events?regardingAny=$parentDeploymentTaskId&spaces=$spaceId&includeSystem=true" -apiKey $octopusApiKey -method "GET"
    
    foreach ($parentDeploymentEvent in $parentDeploymentEvents.Items)
    {
        Write-OctopusVerbose "Checking $($parentDeploymentEvent.Message) for manual intervention"
        if ($parentDeploymentEvent.Message -like "Submitted interruption*")
        {
            Write-OctopusVerbose "The event $($parentDeploymentEvent.Id) is a manual intervention approval event which was approved by $($parentDeploymentEvent.Username)."

            $approverExists = $approverList | Where-Object {$_.Id -eq $parentDeploymentEvent.UserId}        

            if ($null -eq $approverExists)
            {
                $approverInformation = @{
                    Id = $parentDeploymentEvent.UserId;
                    Username = $parentDeploymentEvent.Username;
                    Teams = @()
                }

                $approverInformation.Teams = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "teammembership?userId=$($approverInformation.Id)&spaces=$spaceId&includeSystem=true" -apiKey $octopusApiKey -method "GET"            

                Write-OctopusVerbose "Adding $($approverInformation.Id) to the approval list"
                $approverList += $approverInformation
            }        
        }
    }

    return $approverList
}

function Submit-ChildProjectDeploymentForAutoApproval
{
    param (
        $createdDeployment,
        $parentDeploymentApprovers,
        $defaultUrl,
        $octopusApiKey,
        $spaceId,
        $parentProjectName,
        $parentReleaseNumber,
        $parentEnvironmentName,
        $parentDeploymentTaskId,
        $approvalTenant
    )

    Write-OctopusSuccess "The task has a pending manual intervention.  Checking parent approvals."    
    $manualInterventionInformation = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "interruptions?regarding=$($createdDeployment.TaskId)" -method "GET" -apiKey $octopusApiKey -spaceId $spaceId -ignoreCache $true
    foreach ($manualIntervention in $manualInterventionInformation.Items)
    {
        if ($manualIntervention.IsPending -eq $false)
        {
            Write-OctopusInformation "This manual intervention has already been approved.  Proceeding onto the next one."
            continue
        }

        if ($manualIntervention.CanTakeResponsibility -eq $false)
        {
            Write-OctopusSuccess "The user associated with the API key doesn't have permissions to take responsibility for the manual intervention."
            Write-OctopusSuccess "If you wish to leverage the auto-approval functionality give the user permissions."
            continue
        }        

        $automaticApprover = $null
        Write-OctopusVerbose "Checking to see if one of the parent project approvers is assigned to one of the manual intervention teams $($manualIntervention.ResponsibleTeamIds)"
        foreach ($approver in $parentDeploymentApprovers)
        {
            foreach ($approverTeam in $approver.Teams)
            {
                Write-OctopusVerbose "Checking to see if $($manualIntervention.ResponsibleTeamIds) contains $($approverTeam.TeamId)"
                if ($manualIntervention.ResponsibleTeamIds -contains $approverTeam.TeamId)
                {
                    $automaticApprover = $approver
                    break
                }
            }

            if ($null -ne $automaticApprover)
            {
                break
            }
        }

        if ($null -ne $automaticApprover)
        {
            Write-OctopusVerbose "Found matching approvers, attempting to auto approve."
            if ($manualIntervention.HasResponsibility -eq $false)
            {
                Write-OctopusInformation "Taking over responsibility for this manual intervention."
                $takeResponsiblilityResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "interruptions/$($manualIntervention.Id)/responsible" -method "PUT" -apiKey $octopusApiKey -spaceId $spaceId -ignoreCache $true
                Write-OctopusVerbose "Response from taking responsibility $($takeResponsiblilityResponse.Id)"
            }
            
            if ($null -ne $approvalTenant)
            {
                $approvalMessage = "Parent project $parentProjectName release $parentReleaseNumber to $parentEnvironmentName for the tenant $($approvalTenant.Name) with the task id $parentDeploymentTaskId was approved by $($automaticApprover.UserName)."
            }
            else
            {
                $approvalMessage = "Parent project $parentProjectName release $parentReleaseNumber to $parentEnvironmentName with the task id $parentDeploymentTaskId was approved by $($automaticApprover.UserName)."
            }

            $submitApprovalBody = @{
                Instructions = $null;
                Notes = "Auto-approving this deployment. $approvalMessage That user is a member of one of the teams this manual intervention requires.  You can view that deployment $defaultUrl/app#/$spaceId/tasks/$parentDeploymentTaskId";
                Result = "Proceed"
            }
            $submitResult = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "interruptions/$($manualIntervention.Id)/submit" -method "POST" -apiKey $octopusApiKey -item $submitApprovalBody -spaceId $spaceId -ignoreCache $true
            Write-OctopusSuccess "Successfully auto approved the manual intervention $($submitResult.Id)"
        }
        else
        {
            Write-OctopusSuccess "Couldn't find an approver to auto-approve the child project.  Waiting until timeout or child project is approved."    
        }
    }
}

function Get-ReleaseNotes
{
	param (
    	$releaseToDeploy,
        $deploymentPreview,
        $channel,
        $spaceId,
        $defaultUrl,
        $octopusApiKey
    )
            
    $releaseNotes = @("")
    $releaseNotes += "**Release Information**"
    $releaseNotes += ""

    $packageVersionAdded = @()
    $workItemsAdded = @()
    $commitsAdded = @()

    if ($null -ne $releaseToDeploy.BuildInformation -and $releaseToDeploy.BuildInformation.Count -gt 0)
    {
        $releaseNotes += "- Package Versions"
        foreach ($change in $deploymentPreview.Changes)
        {        
            foreach ($package in $change.BuildInformation)
            {
                $packageInformation = "$($package.PackageId).$($package.Version)"
                if ($packageVersionAdded -notcontains $packageInformation)
                {
                    $releaseNotes += "  - $packageInformation"
                    $packageVersionAdded += $packageInformation
                }
            }
        }

		$releaseNotes += ""
        $releaseNotes += "- Work Items"
        foreach ($change in $deploymentPreview.Changes)
        {        
            foreach ($workItem in $change.WorkItems)
            {            
                if ($workItemsAdded -notcontains $workItem.Id)
                {
                    $workItemInformation = "[$($workItem.Id)]($($workItem.LinkUrl)) - $($workItem.Description)"
                    $releaseNotes += "  - $workItemInformation"
                    $workItemsAdded += $workItem.Id
                }
            }
        }

		$releaseNotes += ""
        $releaseNotes += "- Commits"
        foreach ($change in $deploymentPreview.Changes)
        {        
            foreach ($commit in $change.Commits)
            {            
                if ($commitsAdded -notcontains $commit.Id)
                {
                    $commitInformation = "[$($commit.Id)]($($commit.LinkUrl)) - $($commit.Comment)"
                    $releaseNotes += "  - $commitInformation"
                    $commitsAdded += $commit.Id
                }
            }
        }            
    }
    else
    {
        $releaseNotes += $releaseToDeploy.ReleaseNotes
        $releaseNotes += ""
        $releaseNotes += "Package Versions"  
        
        $releaseDeploymentTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "deploymentprocesses/$($releaseToDeploy.ProjectDeploymentProcessSnapshotId)/template?channel=$($channel.Id)&releaseId=$($releaseToDeploy.Id)" -method "GET" -apiKey $octopusApiKey -spaceId $spaceId
        
        foreach ($package in $releaseToDeploy.SelectedPackages)
        {
        	Write-OctopusVerbose "Attempting to find $($package.StepName) and $($package.ActionName)"
            
            $deploymentProcessPackageInformation = $releaseDeploymentTemplate.Packages | Where-Object {$_.StepName -eq $package.StepName -and $_.actionName -eq $package.ActionName}
            if ($null -ne $deploymentProcessPackageInformation)
            {
                $packageInformation = "$($deploymentProcessPackageInformation.PackageId).$($package.Version)"
                if ($packageVersionAdded -notcontains $packageInformation)
                {
                    $releaseNotes += "  - $packageInformation"
                    $packageVersionAdded += $packageInformation
                }
            }
        }
    }

    return $releaseNotes -join "`n"
}

function Get-QueueDate
{
	param ( 
    	$futureDeploymentDate
    )
    
    if ([string]::IsNullOrWhiteSpace($futureDeploymentDate) -or $futureDeploymentDate -eq "N/A")
    {
    	return $null
    }
    
    [datetime]$outputDate = New-Object DateTime
    $currentDate = Get-Date

    if ([datetime]::TryParse($futureDeploymentDate, [ref]$outputDate) -eq $false)
    {
        Write-OctopusCritical "The suppplied date $futureDeploymentDate cannot be parsed by DateTime.TryParse.  Please verify format and try again.  Please [refer to Microsoft's Documentation](https://docs.microsoft.com/en-us/dotnet/api/system.datetime.tryparse) on supported formats."
        exit 1
    }
    
    if ($currentDate -gt $outputDate)
    {
    	Write-OctopusCritical "The supplied date $futureDeploymentDate is set for the past.  All queued deployments must be in the future."
        exit 1
    }
    
    return $outputDate
}

function Get-QueueExpiryDate
{
	param (
    	$queueDate
    )
    
    if ($null -eq $queueDate)
    {
    	return $null
    }
    
    return $queueDate.AddHours(1)
}

function Insert-EmptyOutputVariables
{
	param (
    	$releaseToDeploy
    )
    
	if ($null -ne $releaseToDeploy)
    {
		Set-OctopusVariable -Name "ReleaseToPromote" -Value $($releaseToDeploy.Version)
        Set-OctopusVariable -Name "ReleaseNotes" -value "Release already deployed to destination environment."
    }
    else
    {
    	Set-OctopusVariable -Name "ReleaseToPromote" -Value "N/A"
        Set-OctopusVariable -Name "ReleaseNotes" -value "No release found"
    }        
    
    Write-OctopusInformation "Setting the output variable ChildReleaseToDeploy to $false"
    Set-OctopusVariable -Name "ChildReleaseToDeploy" -Value $false
}

function Get-ApprovalDeploymentTaskId
{
	param (
    	$autoapproveChildManualInterventions,
        $parentDeploymentTaskId,
        $parentReleaseId,
        $parentEnvironmentName,
        $approvalEnvironmentName,
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $parentChannelId,    
        $parentEnvironmentId,
        $approvalTenant,
        $parentProject
    )
    
    if ($autoapproveChildManualInterventions -eq $false)
    {
    	Write-OctopusInformation "Auto approvals are disabled, skipping pulling the approval deployment task id"
        return $null
    }
    
    if ([string]::IsNullOrWhiteSpace($approvalEnvironmentName) -eq $true)
    {
    	Write-OctopusInformation "Approval environment not supplied, using the current environment id for approvals."
        return $parentDeploymentTaskId
    }
    
    if ($approvalEnvironmentName.ToLower().Trim() -eq $parentEnvironmentName.ToLower().Trim())
    {
        Write-OctopusInformation "The approval environment is the same as the current environment, using the current task id $parentDeploymentTaskId"
        return $parentDeploymentTaskId
    }
    
    $approvalEnvironment = Get-OctopusEnvironmentByName -environmentName $approvalEnvironmentName -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey
    $releaseDeploymentList = Get-ListFromOctopusApi -octopusUrl $defaultUrl -endPoint "releases/$parentReleaseId/deployments?skip=0&take=1000" -method "GET" -apiKey $octopusApiKey -spaceId $spaceId -propertyName "Items"
    
    $lastDeploymentTime = $(Get-Date).AddYears(-50)
    $approvalTaskId = $null
    foreach ($deployment in $releaseDeploymentList)
    {
        if ($deployment.EnvironmentId -ne $approvalEnvironment.Id)
        {
            Write-OctopusInformation "The deployment $($deployment.Id) deployed to $($deployment.EnvironmentId) which doesn't match $($approvalEnvironment.Id).  Moving onto the next deployment."
            continue
        }

        if ($null -ne $approvalTenant -and $null -ne $deployment.TenantId -and $deployment.TenantId -ne $approvalTenant.Id)
        {
            Write-OctopusInformation "The deployment $($deployment.Id) was deployed to the correct environment, $($approvalEnvironment.Id), but the deployment tenant $($deployment.TenantId) doesn't match the approval tenant $($approvalTenant.Id).  Moving onto the next deployment."
            continue
        }
        
        Write-OctopusInformation "The deployment $($deployment.Id) was deployed to the approval environment $($approvalEnvironment.Id)."

        $deploymentTask = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $null -endPoint "tasks/$($deployment.TaskId)" -apiKey $octopusApiKey -Method "Get"
        if ($deploymentTask.IsCompleted -eq $false)
        {
            Write-OctopusInformation "The deployment $($deployment.Id) is being deployed to the approval environment, but it hasn't completed, moving onto the next deployment."
            continue
        }

        if ($deploymentTask.IsCompleted -eq $true -and $deploymentTask.FinishedSuccessfully -eq $false)
        {
            Write-Information "The deployment $($deployment.Id) was deployed to the approval environment, but it encountered a failure, moving onto the next deployment."
            continue
        }

        if ($deploymentTask.StartTime -gt $lastDeploymentTime)
        {
            $approvalTaskId = $deploymentTask.Id
            $lastDeploymentTime = $deploymentTask.StartTime
        }
    }        

    if ($null -eq $approvalTaskId)
    {
    	Write-OctopusVerbose "Unable to find a deployment to the environment, determining if it should've happened already."
        $channelInformation = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "channels/$parentChannelId" -method "GET" -apiKey $octopusApiKey -spaceId $spaceId
        $lifecyclePhases = Get-OctopusLifeCyclePhases -channel $channelInformation -defaultUrl $defaultUrl -spaceId $spaceId -OctopusApiKey $octopusApiKey -project $parentProject        
        
        $foundDestinationFirst = $false
        $foundApprovalFirst = $false
        
        foreach ($phase in $lifecyclePhases)
        {
        	if (Test-PhaseContainsEnvironmentId -phase $phase -environmentId $parentEnvironmentId)
            {
            	if ($foundApprovalFirst -eq $false)
                {
                	$foundDestinationFirst = $true
                }
            }
            
            if (Test-PhaseContainsEnvironmentId -phase $phase -environmentId $approvalEnvironment.Id)
            {
            	if ($foundDestinationFirst -eq $false)
                {
                	$foundApprovalFirst = $true
                }
            }
        }
        
        $messageToLog = "Unable to find a deployment for the environment $approvalEnvironmentName.  Auto approvals are disabled."
        if ($foundApprovalFirst -eq $true)
        {
        	Write-OctopusWarning $messageToLog
        }
        else
        {
        	Write-OctopusInformation $messageToLog
        }
        
        return $null
    }

    return $approvalTaskId
}

function Invoke-RefreshVariableSnapshot
{
	param (
    	$refreshVariableSnapShot,
        $whatIf,
        $releaseToDeploy,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )
    
    Write-OctopusVerbose "Checking to see if variable snapshot will be updated."
    
    if ($refreshVariableSnapShot -eq "No")
    {
    	Write-OctopusVerbose "Refreshing variables is set to no, skipping"
    	return
    }
    
    $releaseDeploymentTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "releases/$($releaseToDeploy.Id)/deployments/template" -spaceId $spaceId -method GET -apiKey $octopusApiKey
    
    if ($releaseDeploymentTemplate.IsVariableSetModified -eq $false -and $releaseDeploymentTemplate.IsLibraryVariableSetModified -eq $false)
    {
    	Write-OctopusVerbose "Variables have not been updated since release creation, skipping"
        return
    }
    
    if ($whatIf -eq $true)
    {
    	Write-OctopusSuccess "Variables have been updated since release creation, whatif set to true, no update will occur."
        return
    }
    
    $snapshotVariables = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "releases/$($releaseToDeploy.Id)/snapshot-variables" -spaceId $spaceId -method "POST" -apiKey $octopusApiKey
    Write-OctopusSuccess "Variables have been modified since release creation.  Variable snapshot was updated on $($snapshotVariables.LastModifiedOn)"
}

function Get-MatchingOctopusDeploymentTasks
{
    param (
        $spaceId,
        $project,
        $tenantToDeploy,
        $tenantIsAssignedToPreviousEnvironments,
        $sourceDestinationEnvironmentInfo,
        $defaultUrl,
        $octopusApiKey
    )

    $taskEndPoint = "tasks?skip=0&take=100&spaces=$spaceId&includeSystem=false&project=$($project.Id)&name=Deploy&states=Success"

    if ($null -ne $tenantToDeploy -and $tenantIsAssignedToPreviousEnvironments -eq $true)
    {
        $taskEndPoint += "&tenant=$($tenantToDeploy.Id)"
    }

    $taskList = @()

    foreach ($sourceEnvironmentId in $sourceDestinationEnvironmentInfo.SourceEnvironmentList)
    {
        $octopusTaskList = Get-ListFromOctopusApi -octopusUrl $DefaultUrl -endPoint "$($taskEndPoint)&environment=$sourceEnvironmentId" -spaceId $null -apiKey $octopusApiKey -method "GET" -propertyName "Items"
        $taskList += $octopusTaskList
    }

    $orderedTaskList = @($taskList | Sort-Object -Property StartTime -Descending)
    Write-OctopusVerbose "We have $($orderedTaskList.Count) number of tasks to loop through"

    return $orderedTaskList
}

function Get-TaskDetails
{
    param (
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $taskId,
        $lastEnhancedLoggingWriteTime
    )

    $taskDetails = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -endPoint "tasks/$taskId/details" -method 'GET' -ignoreCache $true
    $activityLogs = $taskDetails.ActivityLogs
    $writeStepName = $writeTargetName = $true
    $returnTime = [datetime]::MinValue

    foreach ($step in $activityLogs.Children)
    {
        foreach ($target in $step.Children)
        {
            foreach ($logElement in $target.LogElements)
            {
                $occurredAt = [datetime]($logElement.OccurredAt)
                if ($occurredAt -gt $lastEnhancedLoggingWriteTime)
                {
                    if ($writeStepName -eq $true)
                    {
                        $trailingCount = 66 - $step.Name.Length
                        if ($trailingCount -lt 0) { $trailingCount = 0 }
                        Write-OctopusInformation "╔═ $($step.Name) $("═" * $trailingCount)"
                        $writeStepName = $false
                    }
                    if ($writeTargetName -eq $true)
                    {
                        $trailingCount = 64 - $target.Name.Length
                        if ($trailingCount -lt 0) { $trailingCount = 0 }
                        Write-OctopusInformation "║ ┌─ $($target.Name) $('─' * $trailingCount)"
                        $writeTargetName = $false
                    }
                    Write-OctopusInformation "║ │ $($logElement.MessageText)"
                    if ($occurredAt -gt $returnTime) { $returnTime = $occurredAt}
                }
            }
            if ($writeTargetName -eq $false)
            {
                Write-OctopusInformation "║ └$('─' * 67)"
                $writeTargetName = $true
            }
        }
        if ($writeStepName -eq $false)
        {
            Write-OctopusInformation "╚$('═' * 69)"
            $writeStepName = $true
        }
    }

    return $returnTime
}

function Get-ReleaseToDeployFromTaskList
{
    param (
        $taskList,
        $channel,
        $releaseNumber,
        $tenantToDeploy,
        $sourceDestinationEnvironmentInfo,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $isPromotionMode
    )
    
    foreach ($task in $taskList)
    {
        Write-OctopusVerbose "Pulling the deployment information for $($task.Id)"
        $deploymentInformation = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "deployments/$($task.Arguments.DeploymentId)" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"

        if ($deploymentInformation.ChannelId -ne $channel.Id)
        {
            Write-OctopusInformation "The deployment was not for the channel we want to deploy to, moving onto next task."
            continue
        }

        Write-OctopusVerbose "Pulling the release information for $($deploymentInformation.Id)"
        $releaseInformation = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "releases/$($deploymentInformation.ReleaseId)" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"
        
        if ($isPromotionMode -eq $false)
        {
            Write-OctopusInformation "Current mode is set to redeploy, the release is for the correct channel and was successful, using it."            
            return $releaseInformation
        }

        if ([string]::IsNullOrWhiteSpace($releaseNumber) -eq $false -and $releaseInformation.Version -notlike $releaseNumber)
        {
            Write-OctopusInformation "The release version $($releaseInformation.Version) does not match $releaseNumber.  Moving onto the next task."
            continue
        }

        $releaseCanBeDeployed = Get-ReleaseCanBeDeployedToTargetEnvironment -defaultUrl $defaultUrl -release $releaseInformation -spaceId $spaceId -octopusApiKey $octopusApiKey -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -tenantToDeploy $tenantToDeploy -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode

        if ($releaseCanBeDeployed -eq $true)
        {
            Write-OctopusInformation "The release $($releaseInformation.Version) can be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)."
            return $releaseInformation                                    
        }

        Write-OctopusInformation "The release $($releaseInformation.Version) cannot be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name).  Moving onto next task"
    } 
    
    return $null
}

function Get-ReleaseToDeployFromChannel
{
    param (
        $channel,
        $releaseNumber,
        $tenantToDeploy,
        $sourceDestinationEnvironmentInfo,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey,
        $isPromotionMode,
        $isAlwaysLatestMode
    )

    if ([string]::IsNullOrWhiteSpace($releaseNumber) -eq $false)
    {        
        $urlReleaseNumber = $releaseNumber.Replace("*", "")
        Write-OctopusInformation "The release number was sent in, sending $urlReleaseNumber to the channel endpoint to have the server filter on that number first."
        $releaseChannelList = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "channels/$($channel.Id)/releases?skip=0&take=100&searchByVersion=$urlReleaseNumber" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"    
    }
    else
    {
        Write-OctopusInformation "The release number was not sent in, attempting to find the latest release from the channel to deploy."
        $releaseChannelList = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint "channels/$($channel.Id)/releases?skip=0&take=100" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"    
    }
    
    Write-OctopusInformation "There are $($releaseChannelList.Items.Count) potential releases to go through."

    foreach ($releaseInformation in $releaseChannelList.Items)
    {
        if ([string]::IsNullOrWhiteSpace($releaseNumber) -eq $false -and $releaseInformation.Version -notlike $releaseNumber)
        {
            Write-OctopusInformation "The release version $($releaseInformation.Version) does not match $releaseNumber.  Moving onto the next release in the channel."
            continue
        }

        $releaseCanBeDeployed = Get-ReleaseCanBeDeployedToTargetEnvironment -defaultUrl $defaultUrl -release $releaseInformation -spaceId $spaceId -octopusApiKey $octopusApiKey -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -tenantToDeploy $tenantToDeploy -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode

        if ($releaseCanBeDeployed -eq $true)
        {
            Write-OctopusInformation "The release $($releaseInformation.Version) can be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)."
            return $releaseInformation                                    
        }

        Write-OctopusInformation "The release $($releaseInformation.Version) cannot be deployed to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name).  Moving onto next release in the channel."
    }

    return $null
}

function Get-ReleaseHasAlreadyBeenPromotedToTargetEnvironment
{
    param (
        $releaseToDeploy,
        $tenantToDeploy,
        $sourceDestinationEnvironmentInfo,
        $isPromotionMode,
        $isAlwaysLatestMode,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    if ($isPromotionMode -eq $false -and $isAlwaysLatestMode -eq $false)
    {
        Write-OctopusInformation "Currently in redeploy mode, of course the release has already been deployed to the target environment.  Exiting the Release Has Already Been Promoted To Target Environment check."
        return $true
    }

    Write-OctopusVerbose "Pulling the last release for the target environment to see if the release to deploy is the latest one in that environment."
    $taskEndPoint = "tasks?skip=0&take=1&spaces=$spaceId&includeSystem=false&project=$($releaseToDeploy.ProjectId)&name=Deploy&states=Success&environment=$($sourceDestinationEnvironmentInfo.TargetEnvironment.Id)"

    if ($null -ne $tenantToDeploy)
    {
        $taskEndPoint += "&tenant=$($tenantToDeploy.Id)"
    }

    $octopusTaskList = Get-ListFromOctopusApi -octopusUrl $DefaultUrl -endPoint "$taskEndPoint" -spaceId $null -apiKey $octopusApiKey -method "GET" -propertyName "Items"

    if ($octopusTaskList.Count -eq 0)
    {
        Write-OctopusInformation "There have been no releases to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name) for this project."
        return $false
    }

    $task = $octopusTaskList[0]
    $deploymentInformation = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "deployments/$($task.Arguments.DeploymentId)" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"

    if ($releaseToDeploy.Id -eq $deploymentInformation.ReleaseId)
    {
        Write-OctopusInformation "The release to deploy $($release.ReleaseNumber) is the last successful release to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)"
        return $true
    }

    Write-OctopusInformation "The release to deploy $($release.ReleaseNumber) is different than the last successful release to $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name)"
    return $false
}

function Get-MachineIdsFromMachineNames
{
    param (
        $targetMachines,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    $targetMachineList = $targetMachines -split ","
    $translatedList = @()

    foreach ($machineName in $targetMachineList)
    {
    	$trimmedMachineName = $machineName.Trim()
        Write-OctopusVerbose "Translating $trimmedMachineName into an Octopus Id"
    	if ($trimmedMachineName -like "Machines-*")
        {
        	Write-OctopusVerbose "$trimmedMachineName is already an Octopus Id, adding it to the list"
        	$translatedList += $machineName
            continue
        }
        
        $machineObject = Get-OctopusItemByName -itemName $trimmedMachineName -itemType "Deployment Target" -endpoint "machines" -defaultValue $null -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey

        $translatedList += $machineObject.Id
    }

    return $translatedList -join ","
}

function Write-ReleaseInformation
{
    param (
        $releaseToDeploy,
        $environmentList
    )

    $releaseDeployments = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "releases/$($releaseToDeploy.Id)/deployments" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"
    $releaseEnvironmentList = @()

    foreach ($deployment in $releaseDeployments.Items)
    {        
        $releaseEnvironment = $environmentList | Where-Object {$_.Id -eq $deployment.EnvironmentId }
        
        if ($null -ne $releaseEnvironment -and $releaseEnvironmentList -notcontains $releaseEnvironment.Name)
        {
            Write-OctopusVerbose "Adding $($releaseEnvironment.Name) to the list of environments this release has been deployed to"
            $releaseEnvironmentList += $releaseEnvironment.Name
        }                
    }
    
    if ($releaseEnvironmentList.Count -gt 0)
    {
        Write-OctopusSuccess "The release to deploy is $($releaseToDeploy.Version) which has been deployed to $($releaseEnvironmentList -join ",")"
    }
    else
    {
        Write-OctopusSuccess "The release to deploy is $($releaseToDeploy.Version) which currently has no deployments."    
    }
}

function Get-GuidedFailureMode
{
	param (
    	$projectToDeploy,
        $environmentToDeployTo
    )
    
    Write-OctopusInformation "Checking $($projectToDeploy.DefaultGuidedFailureMode) and $($environmentToDeployTo.UseGuidedFailure) to determine guided failure mode."
    
    if ($projectToDeploy.DefaultGuidedFailureMode -eq "EnvironmentDefault" -and $environmentToDeployTo.UseGuidedFailure -eq $true)
    {
    	Write-OctopusInformation "Guided failure for the project is set to environment default, and destination environment says to use guided failure.  Setting guided failure to true."
        return $true
    }
    
    if ($projectToDeploy.DefaultGuidedFailureMode -eq "On")
    {
    	Write-OctopusInformation "Guided failure for the project is set to always use guided falure.  Setting guided failure to true."
        return $true
    }
    
    Write-OctopusInformation "Guided failure is not turned on for the project nor the environment.  Setting to false."
    return $false
}

Write-OctopusInformation "Octopus SpaceId: $destinationSpaceId"
Write-OctopusInformation "Octopus Deployment Task Id: $parentDeploymentTaskId"
Write-OctopusInformation "Octopus Project Name: $parentProjectName"
Write-OctopusInformation "Octopus Release Number: $parentReleaseNumber"
Write-OctopusInformation "Octopus Release Id: $parentReleaseId"
Write-OctopusInformation "Octopus Environment Name: $parentEnvironmentName"
Write-OctopusInformation "Octopus Release Channel Id: $parentChannelId"
Write-OctopusInformation "Octopus Specific deployment machines: $specificMachines"
Write-OctopusInformation "Octopus Exclude deployment machines: $excludeMachines"
Write-OctopusInformation "Octopus deployment machines: $deploymentMachines"

Write-OctopusInformation "Child Project Name: $projectName"
Write-OctopusInformation "Child Project Space Name: $destinationSpaceName"
Write-OctopusInformation "Child Project Channel Name: $channelName"
Write-OctopusInformation "Child Project Release Number: $releaseNumber"
Write-OctopusInformation "Child Project Error Handle No Release Found: $errorHandleForNoRelease"
Write-OctopusInformation "Destination Environment Name: $environmentName"
Write-OctopusInformation "Source Environment Name: $sourceEnvironmentName"
Write-OctopusInformation "Ignore specific machine mismatch: $ignoreSpecificMachineMismatchValue"
Write-OctopusInformation "Save release notes as artifact: $saveReleaseNotesAsArtifactValue"
Write-OctopusInformation "What If: $whatIfValue"
Write-OctopusInformation "Wait for finish: $waitForFinishValue"
Write-OctopusInformation "Cancel deployment in seconds: $deploymentCancelInSeconds"
Write-OctopusInformation "Scheduling: $futureDeploymentDate"
Write-OctopusInformation "Auto-Approve Child Project Manual Interventions: $autoapproveChildManualInterventionsValue"
Write-OctopusInformation "Approval Environment: $approvalEnvironmentName"
Write-OctopusInformation "Approval Tenant: $approvalTenantName"
Write-OctopusInformation "Refresh Variable Snapshot: $refreshVariableSnapShot"
Write-OctopusInformation "Deployment Mode: $deploymentMode"
Write-OctopusInformation "Target Machine Names: $targetMachines"
Write-OctopusInformation "Deployment Tenant Name: $deploymentTenantName"

$whatIf = $whatIfValue -eq "Yes"
$waitForFinish = $waitForFinishValue -eq "Yes"
$enableEnhancedLogging = $enableEnhancedLoggingValue -eq "Yes"
$ignoreSpecificMachineMismatch = $ignoreSpecificMachineMismatchValue -eq "Yes"
$autoapproveChildManualInterventions = $autoapproveChildManualInterventionsValue -eq "Yes"
$saveReleaseNotesAsArtifact = $saveReleaseNotesAsArtifactValue -eq "Yes"

$verificationPassed = @()
$verificationPassed += Test-RequiredValues -variableToCheck $octopusApiKey -variableName "Octopus API Key"
$verificationPassed += Test-RequiredValues -variableToCheck $destinationSpaceName -variableName "Child Project Space"
$verificationPassed += Test-RequiredValues -variableToCheck $projectName -variableName "Child Project Name"
$verificationPassed += Test-RequiredValues -variableToCheck $environmentName -variableName "Destination Environment Name"

if ($verificationPassed -contains $false)
{
	Write-OctopusInformation "Required values missing"
	Exit 1
}

$isPromotionMode = $deploymentMode -eq "Promote"
$isAlwaysLatestMode = $deploymentMode -eq 'AlwaysLatest'
$spaceId = Get-OctopusSpaceIdByName -spaceName $destinationSpaceName -spaceId $destinationSpaceId -defaultUrl $defaultUrl -OctopusApiKey $octopusApiKey    

Write-OctopusSuccess "The current mode of the step template is $deploymentMode"

if ($isAlwaysLatestMode -eq $true)
{
    Write-OctopusSuccess "Currently in AlwaysLatest mode, release number filter will be ignored, source environment will be set to the target environment, all redeployment checks will be ignored."
}

if ($isPromotionMode -eq $false -and $isAlwaysLatestMode -eq $false)
{
    Write-OctopusSuccess "Currently in redeploy mode, release number filter will be ignored, source environment will be set to the target environment, all redeployment checks will be ignored."
}

if ($isPromotionMode -eq $true -and [string]::IsNullOrWhiteSpace($sourceEnvironmentName) -eq $false -and $sourceEnvironmentName.ToLower().Trim() -eq $environmentName.ToLower().Trim())
{
    Write-OctopusSuccess "The current mode is promotion.  Both the source environment and destination environment are the same.  You cannot promote from the same environment as the source environment.  Exiting.  Change the deployment mode value to redeploy if you want to redeploy."
    Exit 0
}

$specificMachineDeployment = $false
if ([string]::IsNullOrWhiteSpace($specificMachines) -eq $false)
{
	Write-OctopusSuccess "This deployment is targeting the specific machines $specificMachines."
	$specificMachineDeployment = $true
}

if ([string]::IsNullOrWhiteSpace($excludeMachines) -eq $false)
{
	Write-OctopusSuccess "This deployment is excluding the specific machines $excludeMachines.  The machines being deployed to are: $deploymentMachines."
    $specificMachineDeployment = $true
}

if ([string]::IsNullOrWhiteSpace($targetMachines) -eq $false -and $targetMachines -ne "N/A")
{
    Write-OctopusSuccess "You have specified specific machines to target in this deployment.  Ignoring the machines that triggered this deployment."
    $specificMachineDeployment = $true
    $deploymentMachines = Get-MachineIdsFromMachineNames -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -targetMachines $targetMachines
}

$project = Get-OctopusProjectByName -projectName $projectName -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey
$parentProject = Get-OctopusProjectByName -projectName $parentProjectName -defaultUrl $defaultUrl -spaceId $parentSpaceId -octopusApiKey $octopusApiKey
$tenantToDeploy = Get-OctopusTenantByName -tenantName $deploymentTenantName -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey
$targetEnvironment = Get-OctopusEnvironmentByName -environmentName $environmentName -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey
$tenantToDeploy = Test-ProjectTenantSettings -tenantToDeploy $tenantToDeploy -project $project -targetEnvironment $targetEnvironment

$sourceEnvironment = Get-OctopusEnvironmentByName -environmentName $sourceEnvironmentName -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey
$channel = Get-OctopusChannel -channelName $channelName -defaultUrl $defaultUrl -project $project -spaceId $spaceId -octopusApiKey $octopusApiKey
$phaseList = Get-OctopusLifecyclePhases -channel $channel -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -project $project
$sourceDestinationEnvironmentInfo = Get-SourceDestinationEnvironmentInformation -phaseList $phaseList -targetEnvironment $targetEnvironment -sourceEnvironment $sourceEnvironment -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode

if ($deploymentMode -eq 'AlwaysLatest')
{
    Write-OctopusInformation "Finding the latest release that can be deployed."
    $releaseToDeploy = Get-ReleaseToDeployFromChannel -channel $channel -releaseNumber $releaseNumber -tenantToDeploy $tenantToDeploy -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode
}
elseif ($sourceDestinationEnvironmentInfo.FirstLifecyclePhase -eq $false)
{
    $tenantIsAssignedToPreviousEnvironments = Get-TenantIsAssignedToPreviousEnvironments -tenantToDeploy $tenantToDeploy -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -projectId $project.Id -isPromotionMode $isPromotionMode
    $taskList = Get-MatchingOctopusDeploymentTasks -spaceId $spaceId -project $project -tenantToDeploy $tenantToDeploy -tenantIsAssignedToPreviousEnvironments $tenantIsAssignedToPreviousEnvironments -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey
    $releaseToDeploy = Get-ReleaseToDeployFromTaskList -taskList $taskList -channel $channel -releaseNumber $releaseNumber -tenantToDeploy $tenantToDeploy -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -defaultUrl $DefaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -isPromotionMode $isPromotionMode    

    if ($null -eq $releaseToDeploy -and $sourceDestinationEnvironmentInfo.HasRequiredPhase -eq $false)
    {
        Write-OctopusInformation "No release was found that has been deployed.  However, all the phases prior to the destination phase is optional.  Checking to see if any releases exist at the channel level that haven't been deployed."
        $releaseToDeploy = Get-ReleaseToDeployFromChannel -channel $channel -releaseNumber $releaseNumber -tenantToDeploy $tenantToDeploy -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode
    }
}
else
{
    $releaseToDeploy = Get-ReleaseToDeployFromChannel -channel $channel -releaseNumber $releaseNumber -tenantToDeploy $tenantToDeploy -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode
}

$environmentList = Get-ListFromOctopusApi -octopusUrl $defaultUrl -endPoint "environments?skip=0&take=1000" -spaceId $spaceId -propertyName "Items" -apiKey $octopusApiKey

Test-ReleaseToDeploy -releaseToDeploy $releaseToDeploy -errorHandleForNoRelease $errorHandleForNoRelease -releaseNumber $releaseNumber -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -environmentList $environmentList

if ($null -ne $releaseToDeploy)
{
    Write-ReleaseInformation -releaseToDeploy $releaseToDeploy -environmentList $environmentList
}

$releaseHasAlreadyBeenDeployed = Get-ReleaseHasAlreadyBeenPromotedToTargetEnvironment -releaseToDeploy $releaseToDeploy -tenantToDeploy $tenantToDeploy -sourceDestinationEnvironmentInfo $sourceDestinationEnvironmentInfo -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -isPromotionMode $isPromotionMode -isAlwaysLatestMode $isAlwaysLatestMode

$deploymentPreview = Get-DeploymentPreview -releaseToDeploy $releaseToDeploy -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -targetEnvironment $targetEnvironment -deploymentTenant $tenantToDeploy
$childDeploymentSpecificMachines = Get-ChildDeploymentSpecificMachines -deploymentPreview $deploymentPreview -deploymentMachines $deploymentMachines -specificMachineDeployment $specificMachineDeployment
$deploymentFormValues = Get-ValuesForPromptedVariables -formValues $formValues -deploymentPreview $deploymentPreview

$queueDate = Get-QueueDate -futureDeploymentDate $futureDeploymentDate
$queueExpiryDate = Get-QueueExpiryDate -queueDate $queueDate
$useGuidedFailure = Get-GuidedFailureMode -projectToDeploy $project -environmentToDeployTo $targetEnvironment

$createdDeployment = @{
    EnvironmentId = $targetEnvironment.Id;
    ExcludeMachineIds = @();
    ForcePackageDownload = $false;
    ForcePackageRedeployment = $false;
    FormValues = $deploymentFormValues;
    QueueTime = $queueDate;
    QueueTimeExpiry = $queueExpiryDate;
    ReleaseId = $releaseToDeploy.Id;
    SkipActions = @();
    SpecificMachineIds = @($childDeploymentSpecificMachines);
    TenantId = $null;
    UseGuidedFailure = $useGuidedFailure
}

if ($null -ne $tenantToDeploy -and $project.TenantedDeploymentMode -ne "Untenanted")
{
    $createdDeployment.TenantId = $tenantToDeploy.Id
}

if ($whatIf -eq $true)
{    	
    Write-OctopusVerbose "Would have done a POST to /api/$spaceId/deployments with the body:"
    Write-OctopusVerbose $($createdDeployment | ConvertTo-JSON)        
    
    Write-OctopusSuccess "What If set to true."
    Write-OctopusSuccess "Setting the output variable ReleaseToPromote to $($releaseToDeploy.Version)."            
	Set-OctopusVariable -Name "ReleaseToPromote" -Value ($releaseToDeploy.Version)       
}

Write-OctopusVerbose "Getting the release notes"
$releaseNotes = Get-ReleaseNotes -releaseToDeploy $releaseToDeploy -deploymentPreview $deploymentPreview -channel $channel -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey
Write-OctopusSuccess "Setting the output variable ReleaseNotes which contains the release notes from the child project"
Set-OctopusVariable -Name "ReleaseNotes" -value $releaseNotes

Test-ChildProjectDeploymentCanProceed -releaseToDeploy $releaseToDeploy -specificMachineDeployment $specificMachineDeployment -environmentName $environmentName -childDeploymentSpecificMachines $childDeploymentSpecificMachines -project $project -ignoreSpecificMachineMismatch $ignoreSpecificMachineMismatch -deploymentMachines $deploymentMachines -releaseHasAlreadyBeenDeployed $releaseHasAlreadyBeenDeployed -isPromotionMode $isPromotionMode

if ($saveReleaseNotesAsArtifact -eq $true)
{
	$releaseNotes | Out-File "ReleaseNotes.txt"
    $currentDate = Get-Date
	$currentDateFormatted = $currentDate.ToString("yyyy_MM_dd_HH_mm")
    $artifactName = "$($project.Name) $($releaseToDeploy.Version) $($sourceDestinationEnvironmentInfo.TargetEnvironment.Name).ReleaseNotes_$($currentDateFormatted).txt"
    Write-OctopusInformation "Creating the artifact $artifactName"
    
	New-OctopusArtifact -Path "ReleaseNotes.txt" -Name $artifactName
}

Invoke-RefreshVariableSnapshot -refreshVariableSnapShot $refreshVariableSnapShot -whatIf $whatIf -releaseToDeploy $releaseToDeploy -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey

if ($whatif -eq $true)
{
    Write-OctopusSuccess "Exiting because What If set to true."
    Write-OctopusInformation "Setting the output variable ChildReleaseToDeploy to $true"
    Set-OctopusVariable -Name "ChildReleaseToDeploy" -Value $true
    Exit 0
}

$approvalTenant = Get-OctopusApprovalTenant -tenantToDeploy $tenantToDeploy -approvalTenantName $approvalTenantName -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey
$approvalDeploymentTaskId = Get-ApprovalDeploymentTaskId -autoapproveChildManualInterventions $autoapproveChildManualInterventions  -parentDeploymentTaskId $parentDeploymentTaskId -parentReleaseId $parentReleaseId -parentEnvironmentName $parentEnvironmentName -approvalEnvironmentName $approvalEnvironmentName -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -parentChannelId $parentChannelId -parentEnvironmentId $parentEnvironmentId -approvalTenant $approvalTenant -parentProject $parentProject
$parentDeploymentApprovers = Get-ParentDeploymentApprovers -parentDeploymentTaskId $approvalDeploymentTaskId -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey

Create-NewOctopusDeployment -releaseToDeploy $releaseToDeploy -targetEnvironment $targetEnvironment -createdDeployment $createdDeployment -project $project -waitForFinish $waitForFinish -enableEnhancedLogging $enableEnhancedLogging -deploymentCancelInSeconds $deploymentCancelInSeconds -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -parentDeploymentApprovers $parentDeploymentApprovers -parentProjectName $parentProjectName -parentReleaseNumber $parentReleaseNumber -parentEnvironmentName $approvalEnvironmentName -parentDeploymentTaskId $approvalDeploymentTaskId -autoapproveChildManualInterventions $autoapproveChildManualInterventions -approvalTenant $approvalTenant