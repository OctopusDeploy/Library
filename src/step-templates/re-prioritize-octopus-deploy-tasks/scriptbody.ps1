[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$octopusApiKey = $OctopusParameters["TaskPriority.Api.Key"]
$spaceList = $OctopusParameters["TaskPriority.Space.List"]
$environmentList = $OctopusParameters["TaskPriority.Environment.List"]
$projectList = $OctopusParameters["TaskPriority.Project.List"]
$tenantList = $OctopusParameters["TaskPriority.Tenant.List"]
$matchType =  $OctopusParameters["TaskPriority.Match.Type"]
$taskType = $OctopusParameters["TaskPriority.Task.Type"]
$octopusUrl = $OctopusParameters["TaskPriority.Octopus.Url"]
$taskIdList = $OctopusParameters["TaskPriority.TaskId.List"]

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

    $octopusUrlToUse = $OctopusUrl
    if ($OctopusUrl.EndsWith("/"))
    {
        $octopusUrlToUse = $OctopusUrl.Substring(0, $OctopusUrl.Length - 1)
    }

    if ([string]::IsNullOrWhiteSpace($SpaceId))
    {
        $url = "$octopusUrlToUse/api/$EndPoint"
    }
    else
    {
        $url = "$octopusUrlToUse/api/$spaceId/$EndPoint"    
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

function Get-FilteredOctopusItem
{
    param(
        $itemList,
        $itemName
    )

    if ($itemList.Items.Count -eq 0)
    {
        Write-OctopusCritical "Unable to find $itemName.  Exiting with an exit code of 1."
        return $null
    }  

    $item = $itemList.Items | Where-Object { $_.Name -eq $itemName}      

    if ($null -eq $item)
    {
        Write-OctopusCritical "Unable to find $itemName.  Exiting with an exit code of 1."
        return $null
    }

    return $item
}

function Get-OctopusItemByName
{
    param(
        $itemName,
        $itemType,
        $endpoint,        
        $spaceId,
        $octopusUrl,
        $octopusApiKey
    )

    if ([string]::IsNullOrWhiteSpace($itemName))
    {
        return $null
    }

    Write-OctopusInformation "Attempting to find $itemType with the name of $itemName"
    
    $itemList = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "$($endPoint)?partialName=$([uri]::EscapeDataString($itemName))&skip=0&take=100" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"    
    $item = Get-FilteredOctopusItem -itemList $itemList -itemName $itemName

    if ($null -eq $item)
    {
        Write-OctopusInformation "Unable to find $itemType $itemName"    
        return $null
    }
    
    Write-OctopusInformation "Successfully found $itemType $itemName with an id of $($item.Id)"

    return $item
}

function Get-SplitItemIntoArray
{
    param (
        $itemToSplit
    )

    if ($itemToSplit -like "*`n*")
    {
        return @(($itemToSplit -Split "`n").Trim())
    }

    if ($itemToSplit -like "*,*")
    {
        return @(($itemToSplit -Split ",").Trim())
    }

    return @($itemToSplit)
}

function Get-OctopusSpaceList
{
	param(
    	$spaceList,        
        $octopusUrl,
        $octopusApiKey    
    )
    
    if ([string]::IsNullOrWhiteSpace($spaceList))
    {
        $rawOctopusSpaceList = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "spaces?skip=0&take=10000" -spaceId $null -apiKey $octopusApiKey -method "GET"    

        return $rawOctopusSpaceList.Items
    }
    
    $spaceListSplit = @(Get-SplitItemIntoArray -itemToSplit $spaceList)
    $returnList = @()

    foreach ($spaceName in $spaceListSplit)
    {
        if ([string]::IsNullOrWhiteSpace($spaceName) -eq $false)
        {
            $octopusSpace = Get-OctopusItemByName -itemName $spaceName -itemType "Space" -endpoint "spaces" -spaceId $null -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey

            if ($null -ne $octopusSpace)
            {
                $returnList += $octopusSpace
            }            
        }        
    }    
    
    return $returnList
}

function Get-OctopusItemList
{
    param(
        $octopusSpaceList,
        $itemList,
        $itemType,
        $endpoint,
        $octopusApiKey,
        $octopusUrl
    )

    if ([string]::IsNullOrWhiteSpace($itemList))
    {
        Write-Host "The list for $itemType was empty"        
        return @()
    }

    $itemListSplit = @(Get-SplitItemIntoArray -itemToSplit $itemList)
    $returnList = @()
    
    foreach ($itemName in $itemListSplit)
    {
        $splitItem = $itemName -split "::"
        if ($splitItem.Count -gt 1 -and [string]::IsNullOrWhiteSpace($splitItem[1]) -eq $false)
        {
            Write-OctopusInformation "The item $itemName included a space name, only pulling back the information for that space"
            $spaceId = $octopusSpaceList | Where-Object { $_.Name.ToLower().Trim() -eq $splitItem[1].ToLower().Trim() }

            if ($null -eq $spaceId)
            {
                Write-OctopusInformation "The space name $($splitItem[1]) was not included in the space filter.  Skipping this option."
                continue
            }

            $octopusItem = Get-OctopusItemByName -itemName $splitItem[0] -itemType $itemType -endpoint $endpoint -spaceId $spaceId -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey

            if ($null -ne $octopusItem)
            {
                $returnList += $octopusItem
            }

            continue
        }

        foreach ($space in $octopusSpaceList)
        {
            $octopusItem = Get-OctopusItemByName -itemName $itemName -itemType $itemType -endpoint $endpoint -spaceId $space.Id -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey

            if ($null -ne $octopusItem)
            {
                $returnList += $octopusItem
            }
        }
    }

    return $returnList
}

function Get-QueuedOctopusTasks
{
    param (
        $octopusApiKey,
        $octopusUrl
    )

    $queuedTasks = Invoke-OctopusApi -octopusUrl $octopusUrl -endPoint "Tasks?states=Queued&skip=0&take=1000" -spaceId $null -apiKey $octopusApiKey -method "GET" -ignoreCache $true

    $returnList = @()
    $currentTime = $(Get-Date).ToUniversalTime()

    Write-OctopusInformation "Looping through the found items in reverse order because the Queue is FIFO but the return object is ordered by date DESC"

    for($i = $queuedTasks.Items.Count - 1; $i -ge 0; $i--)    
    {
        $task = $queuedTasks.Items[$i]
        
        if ($null -ne $task.QueueTime)
        {
            $compareTime = [DateTime]::Parse($task.QueueTime)
            $compareTime = $compareTime.ToUniversalTime()

            Write-OctopusVerbose "Checking to see if $compareTime is ahead of the $currentTime"
            if ($compareTime -gt $currentTime)
            {
                Write-OctopusInformation "The queued task $($task.Id) has a queue time $($task.QueueTime) in the future.  That means this is a scheduled deployment.  Skipping this task."
                continue
            }
        }

        if ($null -ne $task.StartTime)
        {
            Write-OctopusInformation "The queued task $($task.Id) has a start time, meaning it was picked up, work was done, then it was added back to the queue.  Skipping."
            continue
        }

        if ($true -eq $task.HasPendingInterruptions)
        {
            Write-OctopusInformation "The task $($task.Id) has pending interruptions, this means the deployment has started and is awaiting someone to respond.  Skipping this task."
            continue
        }

        $returnList += $task
    }

    return $returnList
}

function Test-OctopusListHasId
{
    param (
        $octopusList,
        $octopusId
    )

    $findItem = $octopusList | Where-Object { $_.Id -eq $octopusId }

    if ($null -eq $findItem)
    {
        return $false
    }

    return $true
}

function Get-RunbookRunDetailsFromTask
{
    param (
        $runbookTask,
        $octopusUrl,
        $octopusApiKey
    )

    return Invoke-OctopusApi -endPoint "runbookRuns/$($runbookTask.Arguments.RunbookRunId)" -octopusUrl $octopusUrl -spaceId $runbookTask.SpaceId -apiKey $octopusApiKey -method "GET"
}

function Get-DeploymentDetailsFromTask
{
    param (
        $deploymentTask,
        $octopusUrl,
        $octopusApiKey
    )

    return Invoke-OctopusApi -endPoint "deployments/$($deploymentTask.Arguments.DeploymentId)" -octopusUrl $octopusUrl -spaceId $deploymentTask.SpaceId -apiKey $octopusApiKey -method "GET"
}

Write-OctopusInformation "Space List: $spaceList"
Write-OctopusInformation "Environment List: $environmentList"
Write-OctopusInformation "Project List: $projectList"
Write-OctopusInformation "Tenant List: $tenantList"
Write-OctopusInformation "Octopus URL: $octopusUrl"
Write-OctopusInformation "Match Type: $matchType"
Write-OctopusInformation "Task Id List: $taskIdList"

$queuedTasks = @(Get-QueuedOctopusTasks -octopusApiKey $octopusApiKey -octopusUrl $octopusUrl)

if ($queuedTasks.Length -eq 0)
{
    Write-OctopusSuccess "No queued tasks found that can block a deployment.  Exiting."
    exit 0
}

$octopusInformation = @{
    TaskIdList = @(Get-SplitItemIntoArray -itemToSplit $taskIdList)
}

if ([string]::IsNullOrWhiteSpace($taskIdList))
{
    $octopusInformation.SpaceList = @(Get-OctopusSpaceList -spaceList $spaceList -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey)

    $octopusInformation.EnvironmentList = @(Get-OctopusItemList -octopusSpaceList $octopusInformation.SpaceList -itemList $environmentList -itemType "Environment" -endpoint "environments" -octopusApiKey $octopusApiKey -octopusUrl $octopusUrl)
    $octopusInformation.HasEnvironmentFilter = $octopusInformation.EnvironmentList.Count -gt 0

    $octopusInformation.ProjectList = @(Get-OctopusItemList -octopusSpaceList $octopusInformation.SpaceList -itemList $projectList -itemType "Project" -endpoint "projects" -octopusApiKey $octopusApiKey -octopusUrl $octopusUrl)
    $octopusInformation.HasProjectFilter = $octopusInformation.ProjectList.Count -gt 0

    $octopusInformation.TenantList = @(Get-OctopusItemList -octopusSpaceList $octopusInformation.SpaceList -itemList $tenantList -itemType "Tenant" -endpoint "tenants" -octopusApiKey $octopusApiKey -octopusUrl $octopusUrl)
    $octopusInformation.HasTenantFilter = $octopusInformation.TenantList.Count -gt 0

    if ($octopusInformation.EnvironmentList.Count -eq 0 -and $octopusInformation.ProjectList.Count -eq 0 -and $octopusInformation.TenantList.Count -eq 0)
    {
        Write-OctopusCritical "No environments OR projects OR tenants provided to filter on.  You must provide at least one environment OR project OR tenant."
        exit 1
    }

    Write-OctopusSuccess "Going to look for any $taskType in the spaces ($(($octopusInformation.SpaceList | Select-Object -ExpandProperty Id) -join ", ")) matching "
    Write-OctopusSuccess "Environments ($(($octopusInformation.EnvironmentList | Select-Object -ExpandProperty Id) -join " OR ")) $matchType"
    Write-OctopusSuccess "Projects ($(($octopusInformation.ProjectList | Select-Object -ExpandProperty Id) -join " OR ")) $matchType"
    Write-OctopusSuccess "Tenants ($(($octopusInformation.TenantList | Select-Object -ExpandProperty Id) -join " OR "))"
}
else
{
    Write-OctopusSuccess "Going to look for the tasks ($($octopusInformation.TaskIdList -join ", "))"    
}

$matchingTasks = @()

Write-OctopusInformation "Attempting to find any matching tasks based on the filtering criteria."
foreach ($task in $queuedTasks)
{
    if ($octopusInformation.TaskIdList -contains $task.Id)
    {
        Write-OctopusInformation "The task $($task.Id) was found in the list of task ids.  Adding to list."
        $matchingTasks += $task

        continue
    }

    if ($task.Name -ne "Deploy" -and $task.Name -ne "RunbookRun")
    {
        Write-Information "The task not a deployment or a runbook run.  It is $($task.Description).  Moving onto next task."
        continue
    }

    if ($taskType -ne "Both" -and $taskType -ne $task.Name)
    {
        Write-Information "You have selected to filter on $taskType only and this task is a $($task.Name).  Moving onto the next task."
        continue
    }

    if ((Test-OctopusListHasId -octopusList $octopusInformation.SpaceList -octopusId $task.SpaceId) -eq $false)
    {
        Write-Information "The task is not for any spaces specified.  Moving onto the next task."
        continue
    }

    if ($task.Name -eq "RunbookRun")
    {
        $itemDetails = Get-RunbookRunDetailsFromTask -runbookTask $task -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey
    }
    else
    {
        $itemDetails = Get-DeploymentDetailsFromTask -deploymentTask $task -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey
    }        

    $matchesEnvironmentFilter = $octopusInformation.HasEnvironmentFilter -eq $true -and (Test-OctopusListHasId -octopusList $octopusInformation.EnvironmentList -octopusId $itemDetails.EnvironmentId)
    Write-OctopusInformation "$($task.Name) $($itemDetails.Id) Matches Environment Filter $matchesEnvironmentFilter"

    $matchesProjectFilter = $octopusInformation.HasProjectFilter -eq $true -and (Test-OctopusListHasId -octopusList $octopusInformation.ProjectList -octopusId $itemDetails.ProjectId)
    Write-OctopusInformation "$($task.Name) $($itemDetails.Id) Matches Project Filter $matchesProjectFilter"

    $matchesTenantFilter = $octopusInformation.HasTenantFilter -eq $true -and $null -ne $itemDetails.TenantId -and (Test-OctopusListHasId -octopusList $octopusInformation.TenantList -octopusId $itemDetails.TenantId)
    Write-OctopusInformation "$($task.Name) $($itemDetails.Id) Matches Tenant Filter $matchesTenantFilter"

    if ($matchType -eq "Or" -and ($matchesTenantFilter -eq $true -or $matchesProjectFilter -eq $true -or $matchesEnvironmentFilter -eq $true))
    {
        Write-OctopusInformation "The match type was OR and one of the filters matched, adding this task to the matching list"
        $matchingTasks += $task

        continue
    }

    Write-OctopusInformation "The match type is AND, checking to see if the task matches all the filters"

    if ($octopusInformation.HasEnvironmentFilter -eq $true -and $matchesEnvironmentFilter -eq $false)
    {
        Write-OctopusInformation "The environment filter was provided and the environment $($itemDetails.EnvironmentId) didn't match any environments.  Moving onto next task."
        continue
    }

    if ($octopusInformation.HasProjectFilter -eq $true -and $matchesProjectFilter -eq $false)
    {
        Write-OctopusInformation "The project filter was provided and the project $($itemDetails.ProjectId) didn't match any projects.  Moving onto next task."
        continue
    }

    if ($octopusInformation.HasTenantFilter -eq $true -and $matchesTenantFilter -eq $false)
    {
        Write-OctopusInformation "The tenant filter was provided and the tenant $($itemDetails.TenantId) didn't match any tenants.  Moving onto next task."
        continue
    }

    $matchingTasks += $task
}

if ($matchingTasks.Count -eq 0)
{
    Write-OctopusSuccess "No matching tasks found, exiting."
    exit 0
}

Write-OctopusSuccess "Matching tasks found, checking where they are in the queue."

$matchingTaskCounter = 0

Write-OctopusInformation "Looping through all the queued tasks again to find which tasks to cancel."
foreach ($task in $queuedTasks)
{        
    if ((Test-OctopusListHasId -octopusList $matchingTasks -octopusId $task.Id))
    {
        $matchingTaskCounter += 1
        Write-OctopusInformation "The task $($task.Id) is one we want to move to the top of queue, leaving as is."

        if ($matchingTaskCounter -eq $matchingTasks.Count)
        {
            Write-OctopusSuccess "All the matching tasks we want to move to the top of the queue have been found, exiting"
            break
        }

        continue
    }

    $updatedTask = Invoke-OctopusApi -endPoint "tasks/$($task.Id)" -octopusUrl $octopusUrl -spaceId $null -apiKey $octopusApiKey -method "GET" -ignoreCache $true

    if ($updatedTask.HasBeenPickedUpByProcssor -eq $true)
    {
        Write-OctopusInformation "The task $($task.Id) has already been picked up and started processing, moving on."
        continue
    }

    $canceledTaskResult = Invoke-OctopusApi -endPoint "tasks/$($task.Id)/cancel" -octopusUrl $octopusUrl -spaceId $null -apiKey $octopusApiKey -method "POST" -ignoreCache $true

    Write-OctopusSuccess "Task $($canceledTaskResult.Description) has been successfully cancelled" 

    if ($task.Name -eq "Deploy")
    {
        Write-OctopusInformation "Task $($task.Id) is a deployment, setting up a redeploy."

        $deploymentInfo = Get-DeploymentDetailsFromTask -deploymentTask $task -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey

        $bodyRaw = @{
            EnvironmentId = $deploymentInfo.EnvironmentId
            ExcludedMachineIds = $deploymentInfo.ExcludedMachineIds
            ForcePackageDownload = $deploymentInfo.ForcePackageDownload
            ForcePackageRedeployment = $deploymentInfo.ForcePackageRedeployment
            FormValues = $deploymentInfo.FormValues
            QueueTime = $null
            QueueTimeExpiry = $null
            ReleaseId = $deploymentInfo.ReleaseId
            SkipActions = $deploymentInfo.SkipActions
            SpecificMachineIds = $deploymentInfo.SpecificMachineIds
            TenantId = $deploymentInfo.TenantId
            UseGuidedFailure = $deploymentInfo.UseGuidedFailure
        } 

        $newDeployment = Invoke-OctopusApi -endPoint "deployments" -spaceId $task.SpaceId -octopusUrl $octopusUrl -apiKey $octopusApiKey -method "POST" -item $bodyRaw

        Write-OctopusSuccess "$($task.Description) has been successfully resubmitted with the new id $($newDeployment.TaskId)"        
    }

    if ($task.Name -eq "RunbookRun")
    {
        Write-OctopusInformation "Task $($task.Id) is a runbook run, configuring a re-run."

        $runbookInfo = Get-RunbookRunDetailsFromTask -runbookTask $task -octopusUrl $octopusUrl -octopusApiKey $octopusApiKey

        $bodyRaw = @{
            EnvironmentId = $runbookInfo.EnvironmentId
            ExcludedMachineIds = $runbookInfo.ExcludedMachineIds
            ForcePackageDownload = $runbookInfo.ForcePackageDownload
            ForcePackageRedeployment = $runbookInfo.ForcePackageRedeployment
            FormValues = $runbookInfo.FormValues
            QueueTime = $null
            QueueTimeExpiry = $null
            RunbookId = $runbookInfo.RunbookId
            SkipActions = $runbookInfo.SkipActions
            SpecificMachineIds = $runbookInfo.SpecificMachineIds
            TenantId = $runbookInfo.TenantId
            UseGuidedFailure = $runbookInfo.UseGuidedFailure
            FrozenRunbookProcessId = $runbookInfo.FrozenRunbookProcessId
            RunbookSnapshotId = $runbookInfo.RunbookSnapshotId            
        } 

        $newDeployment = Invoke-OctopusApi -endPoint "runbookRuns" -spaceId $task.SpaceId -octopusUrl $octopusUrl -apiKey $octopusApiKey -method "POST" -item $bodyRaw

        Write-OctopusSuccess "$($task.Description) has been successfully resubmitted with the new id $($newDeployment.TaskId)" 
    }
}

Write-OctopusSuccess "Finished re-prioritizing tasks"