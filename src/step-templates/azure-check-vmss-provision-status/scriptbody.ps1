$vmssScaleSetName = $OctopusParameters["VMSS.ScaleSet.Name"]
$vmssScaleSetResourceGroup = $OctopusParameters["VMSS.ResourceGroup.Name"]
$roleToSearchFor = $OctopusParameters["VMSS.DeploymentTarget.Roles"]
$apiKey = $OctopusParameters["VMSS.Octopus.ApiKey"]
$octopusUrl = $OctopusParameters["VMSS.Octopus.Url"]
$timeoutInMinutes = $OctopusParameters["VMSS.Timeout.Value"]
$timeoutErrorHandle = $OctopusParameters["VMSS.Timeout.ErrorHandle"]
$duplicateRunDetectionInMinutes = $OctopusParameters["VMSS.Duplicate.TimeInMinutes"]
$duplicateRunHandle = $OctopusParameters["VMSS.Duplicate.Handle"]
$excludeOldServers = $OctopusParameters["VMSS.OldServers.ExcludeFromOutput"]

$octopusSpaceId = $OctopusParameters["Octopus.Space.Id"]
$octopusEnvironmentId = $OctopusParameters["Octopus.Environment.Id"]
$octopusTenantId = $OctopusParameters["Octopus.Deployment.Tenant.Id"]
$octopusDeploymentId = $OctopusParameters["Octopus.Deployment.Id"]
$octopusTriggerId = $OctopusParameters["Octopus.Deployment.Trigger.Id"]
$octopusTaskId = $OctopusParameters["Octopus.Task.Id"]
$octopusRunbookRunId = $OctopusParameters["Octopus.RunbookRun.Id"]

function Invoke-OctopusApi
{
    param
    (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $method,
        $item  
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
            Write-Verbose $body

            Write-Host "Invoking $method $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8' 
        }

		Write-Verbose "No data to post or put, calling bog standard invoke-restmethod for $url"
        $result = Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'

        return $result

               
    }
    catch
    {
        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-Error "Unauthorized error returned from $url, please verify API key and try again"
            }
            elseif ($_.Exception.Response.statusCode -eq 403)
            {
                Write-Error "Forbidden error returned from $url, please verify API key and try again"
            }
            else
            {                
                Write-Verbose -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )"
            }            
        }
        else
        {
            Write-Verbose $_.Exception
        }
    }

    Throw "There was an error calling the Octopus API."
}

function Get-QueuedEventInfo
{
    param (
        $octopusRunbookRunId,
        $octopusDeploymentId,
        $octopusSpaceId,
        $octopusUrl,
        $apiKey
    )

    if ([string]::IsNullOrWhiteSpace($octopusRunbookRunId))
    {
        $queuedListRaw = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "events?regardingAny=$($OctopusDeploymentId)&spaces=$($octopusSpaceId)&documentTypes=Deployments&eventCategories=DeploymentQueued" -spaceId $null -apiKey $apiKey -method "GET"
    }
    else
    {
        $queuedListRaw = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "events?regardingAny=$($octopusRunbookRunId)&spaces=$($octopusSpaceId)&documentTypes=RunbookRuns&eventCategories=RunbookRunQueued" -spaceId $null -apiKey $apiKey -method "GET"
    }

    $queuedArray = @($queuedListRaw.Items)

    return @{
        CurrentDeploymentQueued = [DateTime]$queuedArray[0].Occurred
        NumberOfQueuedEvents = $queuedArray.Length
    }
}

function Get-CompletedEventInfo
{
    param (
        $octopusRunbookRunId,
        $octopusDeploymentId,
        $octopusSpaceId,
        $octopusUrl,
        $apiKey
    )

    if ([string]::IsNullOrWhiteSpace($octopusRunbookRunId))
    {      
        $finishedEventListRaw = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "events?regardingAny=$($OctopusDeploymentId)&spaces=$($octopusSpaceId)&documentTypes=Deployments&eventCategories=DeploymentSucceeded,DeploymentFailed&skip=0&take=1" -spaceId $null -apiKey $apiKey -method "GET"
    }
    else
    {
        $finishedEventListRaw = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "events?regardingAny=$($OctopusDeploymentId)&spaces=$($octopusSpaceId)&documentTypes=RunbookRuns&eventCategories=RunbookRunSucceeded,RunbookRunFailed&skip=0&take=1" -spaceId $null -apiKey $apiKey -method "GET"    
    }

    $finishedEventArray = @($finishedEventListRaw.Items)
        
    return [DateTime]$finishedEventArray[0].Occurred
}

function Test-ForDuplicateRun 
{
    param (
        $octopusRunbookRunId,
        $octopusDeploymentId,
        $octopusSpaceId,
        $queuedEventInfo,
        $duplicateRunDetectionInMinutes,
        $duplicateRunHandle,
        $octopusTaskId,
        $octopusUrl,
        $apiKey        
    )

    Write-Host "Checking to see if this current run is a duplicate because of deployment target triggers"
    $duplicateRun = $false

    if ([string]::IsNullOrWhiteSpace($octopusTriggerId) -eq $false)
    {
        Write-Highlight "This run was triggered by a trigger."
        
        Write-Host "The number of items in the queued array is: $($queuedEventInfo.NumberOfQueuedEvents)"
        if ($queuedEventInfo.NumberOfQueuedEvents -gt 1)
        {
            Write-Host "This task has been run before"  

            $previousDeploymentFinished = Get-CompletedEventInfo -octopusRunbookRunId $octopusRunbookRunId -octopusDeploymentId $octopusDeploymentId -octopusSpaceId $octopusSpaceId -octopusUrl $octopusUrl -apiKey $apiKey            
            Write-Host "The current deployment was queued $($queuedEventInfo.CurrentDeploymentQueued) while the previous deployment was finished $previousDeploymentFinished"
            
            $queuedCompletedDifference = $queuedEventInfo.CurrentDeploymentQueued - $previousDeploymentFinished            
            Write-Host "The difference in minutes is $($queuedCompletedDifference.TotalMinutes)"

            if ($queuedCompletedDifference.TotalMinutes -le $duplicateRunDetectionInMinutes)
            {
                Write-Highlight "The previous deployment finished in the last $($queuedCompletedDifference.TotalMinutes) minutes before this was trigger, that is extremely fast.  This is a duplicate run."
                $duplicateRun = $true
                
                if ($duplicateRunHandle.ToLower().Trim() -eq "cancel")
                {
                    Write-Highlight "The duplicate run handle is set to cancel, cancelling current deployment."
                    Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -spaceId $OctopusSpaceId -method "POST" -endPoint "tasks/$($octopusTaskId)/cancel"
                    exit 0    
                }
                else
                {
                    Write-Highlight "The duplicate run handle is set to proceed."
                }
            }
            else
            {
                Write-Highlight "The last deployment finished and this one was queued after $($queuedCompletedDifference.TotalMinutes) minutes has passed which is outside the window of $duplicateRunDetectionInMinutes minutes.  Not a duplicate."
            }
        }	    
        else
        {
            Write-Highlight "This is the first time this release has been deployed to this environment.  This is not a duplicate run."
        }
    }

    return $duplicateRun
}

function Start-WaitForVMSSToFinishProvisioning
{
    param 
    (
        $vmssScaleSetResourceGroup,
        $vmssScaleSetName,
        $timeoutInMinutes
    )

    $vmssState = "Provisioning"
    $startTime = Get-Date

    Write-Host "Will now wait until the VMSS has finished provisioning."

    do
    {
        try
        {
            $vmssInfo = Get-AzVmss -ResourceGroupName $vmssScaleSetResourceGroup -VMScaleSetName $vmssScaleSetName
        }
        catch
        {
            Write-Highlight "Unable to access the scale set $vmssScaleSetName.  Exiting step."
            Write-Host $_.Exception
            exit 0
        }

        Write-Verbose "VMSSInfo: "
        Write-Verbose ($vmssInfo | ConvertTo-JSON -Depth 10)

        $vmssInstanceCount = $vmssInfo.Sku.Capacity
        $vmssState = $vmssInfo.ProvisioningState

        if($vmssState.ToLower().Trim() -ne "provisioning")
        {    
            Write-Highlight "The VMSS $vmssScaleSetName capacity is current set to $vmssInstanceCount with a provisioning state of $vmssState"
        }
        else
        {
            Write-Host "The VMSS is still provisioning, sleeping for 10 seconds then checking again."
            Start-Sleep -Seconds 10
        }
        
        $currentTime = Get-Date
        $dateDifference = $currentTime - $startTime
        
        if ($dateDifference.TotalMinutes -ge $timeoutInMinutes)
        {
            Write-Highlight "We have been waiting $($dateDifference.TotalMinutes) for the VMSS to finish provisioning.  Timeout reached, exiting."
            exit 1
        }   
        
    } While ($vmssState.ToLower().Trim() -eq "provisioning")
}

function Start-WaitForVMsInVMSSToFinishProvisioning
{
    param 
    (
        $vmssScaleSetResourceGroup,
        $vmssScaleSetName,
        $timeoutInMinutes,
        $timeoutErrorHandle
    )

    $vmssVmsAreProvisioning = $false
    $startTime = Get-Date
    $numberOfWaits = 0
    $printVmssVmList = $true

    Write-Highlight "Checking the state of all VMs in the scale set."

    do
    {
        $numberOfWaits += 1
        $vmssVmList = Get-AzVmssVM -ResourceGroupName $vmssScaleSetResourceGroup -VMScaleSetName $vmssScaleSetName
        
        if ($printVmssVmList -eq $true)
        {
            Write-Host ($vmssVmList | ConvertTo-Json -Depth 10)
            $printVmssVmList = $false
        }
        
        $vmssVmsAreProvisioning = $false
        foreach ($vmInfo in $vmssVmList)
        {
            if ($vmInfo.ProvisioningState.ToLower().Trim() -eq "creating")
            {
                $vmssVmsAreProvisioning = $true
                break
            }
        }
        
        if ($vmssVmsAreProvisioning -eq $true)
        {        
            $currentTime = Get-Date
            $dateDifference = $currentTime - $startTime

            if ($dateDifference.TotalMinutes -ge $timeoutInMinutes)
            {
                $vmssVmsAreProvisioning = $false
                if ($timeoutErrorHandle.ToLower().Trim() -eq "error")
                {
                    Write-Highlight "The VMs in the scale have been provisioning for over $timeoutInMinutes.  Error handle is set to error out, exiting with an exit code of 1."
                    exit 1
                }
                
                Write-Highlight "The VMs in the scale have been provisioning for over $timeoutInMinutes.  Going to move on and continue with the deployment for any VMs that have finished provisioning."
            } 
            else
            {
                if ($numberofWaits -ge 10)
                {
                    Write-Highlight "The VMs are still currently provisioning, waiting..."
                    $numberOfWaits = 0
                }
                else
                {            
                    Write-Host "The VMs are still currently provisioning, sleeping for 10 seconds then checking again."
                }
                Start-Sleep -Seconds 10
            }
        }
        else
        {
            Write-Highlight "All the VMs in the VM Scale Set have been provisioned, reconciling them with the list in Octopus."
        }         
    } while ($vmssVmsAreProvisioning -eq $true)
}


Write-Host "ScaleSet Name: $vmssScaleSetName"
Write-Host "Resource Group Name: $vmssScaleSetResourceGroup"
Write-Host "Deployment Target Role to Search For: $roleToSearchFor"
Write-Host "Octopus Url: $octopusUrl"
Write-Host "Timeout In Minutes: $timeoutInMinutes"
Write-Host "Timeout Error Handle: $timeoutErrorHandle"
Write-Host "Duplicate Run Detection in Minutes: $duplicateRunDetectionInMinutes"
Write-Host "Duplicate Run Handle: $duplicateRunHandle"
Write-host "Exclude Old Servers: $excludeOldServers"

Write-Host "Space Id: $octopusSpaceId"
Write-Host "Environment Id: $octopusEnvironmentId"
Write-Host "Tenant Id: $octopusTenantId"
Write-Host "Deployment Id: $octopusDeploymentId"
Write-Host "Trigger Id: $octopusTriggerId"
Write-Host "Task Id: $octopusTaskId"
Write-Host "Runbook Run Id: $octopusRunbookRunId"

if ([string]::IsNullOrWhiteSpace($vmssScaleSetName)) { Write-Error "Scale Set Name is required." }
if ([string]::IsNullOrWhiteSpace($vmssScaleSetResourceGroup)) { Write-Error "Resource Group Name is required." }
if ([string]::IsNullOrWhiteSpace($roleToSearchFor)) { Write-Error "Scale Set Name is required." }
if ([string]::IsNullOrWhiteSpace($octopusUrl)) { Write-Error "Octopus Url is required." }
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Error "Octopus Api Key is required." }
if ([string]::IsNullOrWhiteSpace($timeoutInMinutes)) { Write-Error "Timeout in minutes is required." }
if ([string]::IsNullOrWhiteSpace($timeoutErrorHandle)) { Write-Error "Timeout error handle is required." }
if ([string]::IsNullOrWhiteSpace($duplicateRunDetectionInMinutes)) { Write-Error "Duplicate run detection in minutes is required." }
if ([string]::IsNullOrWhiteSpace($duplicateRunHandle)) { Write-Error "Duplicate run handle is required." }
if ([string]::IsNullOrWhiteSpace($excludeOldServers)) { Write-Error "Exclude old servers is required." }

$queuedEventInfo = Get-QueuedEventInfo -octopusRunbookRunId $octopusRunbookRunId -octopusDeploymentId $octopusDeploymentId -octopusSpaceId $octopusSpaceId -octopusUrl $octopusUrl -apiKey $apiKey

Write-Host "The current deployment was queued at: $($queuedEventInfo.CurrentDeploymentQueued)"

$duplicateRun = Test-ForDuplicateRun -octopusRunbookRunId $octopusRunbookRunId -octopusDeploymentId $octopusDeploymentId -octopusSpaceId $octopusSpaceId  -duplicateRunDetectionInMinutes $duplicateRunDetectionInMinutes -duplicateRunHandle $duplicateRunHandle -queuedEventInfo $queuedEventInfo -octopusTaskId $octopusTaskId -octopusUrl $octopusUrl -apiKey $apiKey

Start-WaitForVMSSToFinishProvisioning -vmssScaleSetResourceGroup $vmssScaleSetResourceGroup -vmssScaleSetName $vmssScaleSetName -timeoutInMinutes $timeoutInMinutes
Start-WaitForVMsInVMSSToFinishProvisioning -vmssScaleSetResourceGroup $vmssScaleSetResourceGroup -vmssScaleSetName $vmssScaleSetName -timeoutInMinutes $timeoutInMinutes -timeoutErrorHandle $timeoutErrorHandle

$vmssVmList = Get-AzVmssVM -ResourceGroupName $vmssScaleSetResourceGroup -VMScaleSetName $vmssScaleSetName
$vmListToReconcile = @()

foreach ($vmInfo in $vmssVmList)
{
	if ($vmInfo.ProvisioningState.ToLower().Trim() -ne "failed")
    {
    	$vmListToReconcile += $vmInfo.OsProfile.ComputerName
    }
}

$octopusDeployTargets = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "machines?environmentIds=$($octopusEnvironmentId)&roles=$($roleToSearchFor)&skip=0&take=1000" -spaceId $octopusSpaceId -apiKey $apiKey -method "GET"
$octopusDeployTargetIds = @()
$octopusDeployTargetNames = @()
$roleList = $roleToSearchFor.Split(",")
foreach ($deploymentTarget in $octopusDeployTargets.Items)
{
	$matchingRole = $true
    foreach ($role in $roleList)
    {
    	if ($deploymentTarget.Roles -notContains ($role.Trim()))
        {
        	Write-Host "The target $($deploymentTarget.Name) does not contain the role $role.  To be considered part of the scale set it has to be assigned to all the roles $roleToSearchFor.  Excluding from reconcilation logic."
            $matchingRole = $false
            break
        }
    }
    
    if ($matchingRole -eq $false)
    {
    	continue
    }
    
    if ([string]::IsNullOrWhiteSpace($octopusTenantId) -eq $false -and $deploymentTarget.TenantIds -notcontains $octopusTenantId)
    {
    	Write-Host "The target $($deploymentTarget.Name) is not assigned to $octopusTenantId.  But the current run is running under the context of that tenant.  Excluding from reconcilation logic."
        continue
    }
    
    $hasMatchingName = $false
    $deploymentTargetNameLowerTrim = $deploymentTarget.Name.ToLower().Trim()

    Write-Host "Attempting to do a match on name"
	foreach ($vmssVM in $vmListToReconcile)
    {
    	$vmssVMLowerTrim = $vmssVM.ToLower().Trim()

        Write-Host "Checking to see if $($deploymentTarget.Name) is like $vmssVM"
        if ($deploymentTargetNameLowerTrim -eq $vmssVMLowerTrim)
        {
            Write-Host "The vmss vm name $vmssVM is equal to to the deployment target name $($deploymentTarget.Name), set matching to true"         
            $hasMatchingName = $true
            break
        }
        if ($deploymentTargetNameLowerTrim -like "*$vmssVMLowerTrim*")
        {   
            Write-Host "The deployment target name $($deploymentTarget.Name) contains the vmss vm name $vmssVM, set matching to true"         
            $hasMatchingName = $true
            break
        }
        elseif ($vmssVMLowerTrim -like "*$deploymentTargetNameLowerTrim*")
        {
            Write-Host "The vmss vm name $vmssVM contains the deployment target name $($deploymentTarget.Name), set matching to true"
            $hasMatchingName = $true
            break
        }
    }
    
    if ($hasMatchingName -eq $false)
    {
    	Write-Highlight "The deployment target $($deploymentTarget.Name) is not in the list of VMs assigned to the scale set, deleting it."
        Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "machines/$($deploymentTarget.Id)" -spaceId $octopusSpaceId -apiKey $apiKey -method "DELETE"
    }
    else
    {
    	Write-Highlight "The deployment target $($deploymentTarget.Name) is in the list of VMS assigned to the scale set, leaving it alone."
        
        $addToOutputArray = $true
        if ($excludeOldServers.ToLower().Trim() -eq "yes")
        {
        	Write-Host "Pulling back the creation event for $($deploymentTarget.Name)"
        	$creationTasks = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "events?regarding=$($deploymentTarget.Id)&spaces=$($octopusSpaceId)&includeSystem=true&eventCategories=Created" -spaceId $null -apiKey $apiKey -method "GET"
            
            $creationDate = @($creationTasks.Items)[0].Occurred
            Write-Host "The deployment target $($deploymentTarget.Name) was created on $creationDate"
            $differenceInCreationTime = [DateTime]$queuedEventInfo.CurrentDeploymentQueued - [DateTime]$creationDate
            
            Write-Host "The difference in minutes between creation date and current task queued time is $($differenceInCreationTime.TotalMinutes) minutes" 
            if ($differenceInCreationTime.TotalMinutes -gt 3)
            {
            	Write-Host "The deployment target $($deploymentTarget.Name) existed for more than 3 minutes before this was ran and the excludeOldServers was set to yes, removing this from the output"
            	$addToOutputArray = $false
            }
        }
        
        if ($addToOutputArray -eq $true)
        {
	        $octopusDeployTargetIds += $deploymentTarget.Id
    	    $octopusDeployTargetNames += $deploymentTarget.Name
        }
    }
}

Write-Highlight "The Azure VM Scale Set $vmssScaleSetName and Octopus Deploy target list have been successfully reconciled."

$vmssHasServersToDeployTo = $octopusDeployTargetIds.Count -gt 0
if ($duplicateRun -eq $true)
{
	Write-Highlight "Duplicate run detected, therefore there are no new servers to deploy to."
    $vmssHasServersToDeployTo = $false
}
elseif ($vmssHasServersToDeployTo -eq $false)
{
	Write-Highlight "There are no servers to deploy to.  Exclude old servers was set to '$excludeOldServers'.  This likely means this was a scale in event or all the servers existed prior to this run."
}

Write-Highlight "Setting the output variable 'VMSSHasServersToDeployTo' to $vmssHasServersToDeployTo."
Set-OctopusVariable -Name "VMSSHasServersToDeployTo" -Value $vmssHasServersToDeployTo

Write-Highlight "Setting the output variable 'VMSSDeploymentTargetIds' to $($octopusDeployTargetIds -join ",")."
Set-OctopusVariable -Name "VMSSDeploymentTargetIds" -Value ($octopusDeployTargetIds -join ",")

Write-Highlight "Setting the output variable 'VMSSDeploymentTargetNames' to $($octopusDeployTargetNames -join ",")."
Set-OctopusVariable -Name "VMSSDeploymentTargetNames" -Value ($octopusDeployTargetNames -join ",")