[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Octopus Variables
$octopusSpaceId = $OctopusParameters["Octopus.Space.Id"]
$parentTaskId = $OctopusParameters["Octopus.Task.Id"]
$parentReleaseId = $OctopusParameters["Octopus.Release.Id"]
$parentChannelId = $OctopusParameters["Octopus.Release.Channel.Id"]
$parentEnvironmentId = $OctopusParameters["Octopus.Environment.Id"]
$parentRunbookId = $OctopusParameters["Octopus.Runbook.Id"]
$parentEnvironmentName = $OctopusParameters["Octopus.Environment.Name"]
$parentReleaseNumber = $OctopusParameters["Octopus.Release.Number"]

# Step Template Parameters
$runbookRunName = $OctopusParameters["Run.Runbook.Name"]
$runbookBaseUrl = $OctopusParameters["Run.Runbook.Base.Url"]
$runbookApiKey = $OctopusParameters["Run.Runbook.Api.Key"]
$runbookEnvironmentName = $OctopusParameters["Run.Runbook.Environment.Name"]
$runbookTenantName = $OctopusParameters["Run.Runbook.Tenant.Name"]
$runbookWaitForFinish = $OctopusParameters["Run.Runbook.Waitforfinish"]
$runbookUseGuidedFailure = $OctopusParameters["Run.Runbook.UseGuidedFailure"]
$runbookUsePublishedSnapshot = $OctopusParameters["Run.Runbook.UsePublishedSnapShot"]
$runbookPromptedVariables = $OctopusParameters["Run.Runbook.PromptedVariables"]
$runbookCancelInSeconds = $OctopusParameters["Run.Runbook.CancelInSeconds"]
$runbookProjectName = $OctopusParameters["Run.Runbook.Project.Name"]
$runbookCustomNotesToggle = $OctopusParameters["Run.Runbook.CustomNotes.Toggle"]
$runbookCustomNotes = $OctopusParameters["Run.Runbook.CustomNotes"]
$parentBranchName = $OctopusParameters["Run.Runbook.CaCBranchName"]

$runbookSpaceName = $OctopusParameters["Run.Runbook.Space.Name"]
$runbookFutureDeploymentDate = $OctopusParameters["Run.Runbook.DateTime"]
$runbookMachines = $OctopusParameters["Run.Runbook.Machines"]
$autoApproveRunbookRunManualInterventions = $OctopusParameters["Run.Runbook.AutoApproveManualInterventions"]
$approvalEnvironmentName = $OctopusParameters["Run.Runbook.ManualIntervention.EnvironmentToUse"]

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

    try 
    {
        Write-Highlight $message     
    }
    catch 
    {
        Write-Host $message ## Using a try-catch block so we can test this locally
    }
    
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
        if ($null -eq $item)
        {
            Write-Verbose "No data to post or put, calling bog standard invoke-restmethod for $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'
        }        
        
        $body = $item | ConvertTo-Json -Depth 10
        Write-Verbose $body

        Write-OctopusInformation "Invoking $method $url"
        return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8'
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
                Write-Error -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )"
            }            
        }
        else
        {
            Write-Verbose $_.Exception
        }
    }

    Throw "There was an error calling the Octopus API please check the log for more details"
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

function GetCheckBoxBoolean
{
	param (
    	[string]$Value
    )
    
    if ([string]::IsNullOrWhiteSpace($value) -eq $true)
    {
    	return $false
    }
    
    return $value -eq "True"
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
        Exit 1
    }  

    $item = $itemList.Items | Where-Object { $_.Name -eq $itemName}      

    if ($null -eq $item)
    {
        Write-OctopusCritical "Unable to find $itemName.  Exiting with an exit code of 1."
        exit 1
    }
    
    if ($item -is [array])
    {
    	Write-OctopusCritical "More than one item exists with the name $itemName.  Exiting with an exit code of 1."
        exit 1
    }

    return $item
}

function Get-OctopusItemFromListEndpoint
{
    param(
        $endpoint,
        $itemNameToFind,
        $itemType,
        $defaultUrl,
        $octopusApiKey,
        $spaceId,
        $defaultValue
    )
    
    if ([string]::IsNullOrWhiteSpace($itemNameToFind))
    {
    	return $defaultValue
    }
    
    Write-OctopusInformation "Attempting to find $itemType with the name of $itemNameToFind"
    
    $itemList = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "$($endpoint)?partialName=$([uri]::EscapeDataString($itemNameToFind))&skip=0&take=100" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"   
    $item = Get-FilteredOctopusItem -itemList $itemList -itemName $itemNameToFind

    Write-OctopusInformation "Successfully found $itemNameToFind with id of $($item.Id)"

    return $item
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
        Write-OctopusVerbose "Translating $machineName to an Id.  First checking to see if it is already an Id."
    	if ($machineName.Trim() -like "Machines*")
        {
            Write-OctopusVerbose "$machineName is already an Id, no need to look that up."
        	$translatedList += $machineName
            continue
        }
        
        $machineObject = Get-OctopusItemFromListEndpoint -itemNameToFind $machineName.Trim() -itemType "Deployment Target" -endpoint "machines" -defaultValue $null -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey

        $translatedList += $machineObject.Id
    }

    return $translatedList
}

function Get-RunbookSnapshotIdToRun
{
    param (
        $runbookToRun,
        $runbookUsePublishedSnapshot,
        $defaultUrl,
        $octopusApiKey,
        $spaceId
    )

    $runbookSnapShotIdToUse = $runbookToRun.PublishedRunbookSnapshotId
    Write-OctopusInformation "The last published snapshot for $runbookRunName is $runbookSnapShotIdToUse"

    if ($null -eq $runbookSnapShotIdToUse -and $runbookUsePublishedSnapshot -eq $true)
    {
        Write-OctopusCritical "Use Published Snapshot was set; yet the runbook doesn't have a published snapshot.  Exiting."
        Exit 1
    }

    if ($runbookUsePublishedSnapshot -eq $true)
    {
        Write-OctopusInformation "Use published snapshot set to true, using the published runbook snapshot."
        return $runbookSnapShotIdToUse
    }

    if ($null -eq $runbookToRun.PublishedRunbookSnapshotId)
    {
        Write-OctopusInformation "There have been no published runbook snapshots, going to create a new snapshot."
        return New-RunbookUnpublishedSnapshot -runbookToRun $runbookToRun -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId
    }

    $runbookSnapShotTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "runbookSnapshots/$($runbookToRun.PublishedRunbookSnapshotId)/runbookRuns/template" -method "Get" -item $null

    if ($runbookSnapShotTemplate.IsRunbookProcessModified -eq $false -and $runbookSnapShotTemplate.IsVariableSetModified -eq $false -and $runbookSnapShotTemplate.IsLibraryVariableSetModified -eq $false)
    {        
        Write-OctopusInformation "The runbook has not been modified since the published snapshot was created.  Checking to see if any of the packages have a new version."    
        $runbookSnapShot = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "runbookSnapshots/$($runbookToRun.PublishedRunbookSnapshotId)" -method "Get" -item $null
        $snapshotTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "runbooks/$($runbookToRun.Id)/runbookSnapShotTemplate" -method "Get" -item $null

        foreach ($package in $runbookSnapShot.SelectedPackages)
        {
            foreach ($templatePackage in $snapshotTemplate.Packages)
            {
                if ($package.StepName -eq $templatePackage.StepName -and $package.ActionName -eq $templatePackage.ActionName -and $package.PackageReferenceName -eq $templatePackage.PackageReferenceName)
                {
                    $packageVersion = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "feeds/$($templatePackage.FeedId)/packages/versions?packageId=$($templatePackage.PackageId)&take=1" -method "Get" -item $null

                    if ($packageVersion -ne $package.Version)
                    {
                        Write-OctopusInformation "A newer version of a package was found, going to use that and create a new snapshot."
                        return New-RunbookUnpublishedSnapshot -runbookToRun $runbookToRun -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId                    
                    }
                }
            }
        }

        Write-OctopusInformation "No new package versions have been found, using the published snapshot."
        return $runbookToRun.PublishedRunbookSnapshotId
    }
    
    Write-OctopusInformation "The runbook has been modified since the snapshot was created, creating a new one."
    return New-RunbookUnpublishedSnapshot -runbookToRun $runbookToRun -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId
}

function New-RunbookUnpublishedSnapshot
{
    param (
        $runbookToRun,
        $defaultUrl,
        $octopusApiKey,
        $spaceId
    )

    $octopusProject = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "projects/$($runbookToRun.ProjectId)" -method "Get" -item $null
    $snapshotTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "runbooks/$($runbookToRun.Id)/runbookSnapShotTemplate" -method "Get" -item $null

    $runbookPackages = Get-RunbookPackages -snapshotTemplate $snapshotTemplate -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -usingCaC $false

    $runbookSnapShotRequest = @{
        FrozenProjectVariableSetId = "variableset-$($runbookToRun.ProjectId)"
        FrozenRunbookProcessId = $($runbookToRun.RunbookProcessId)
        LibraryVariableSetSnapshotIds = @($octopusProject.IncludedLibraryVariableSetIds)
        Name = $($snapshotTemplate.NextNameIncrement)
        ProjectId = $($runbookToRun.ProjectId)
        ProjectVariableSetSnapshotId = "variableset-$($runbookToRun.ProjectId)"
        RunbookId = $($runbookToRun.Id)
        SelectedPackages = @($runbookPackages)
    }

    $newSnapShot = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint "runbookSnapshots" -method "POST" -item $runbookSnapShotRequest

    return $($newSnapShot.Id)
}

function Get-RunbookPackages
{
    param(
        $snapshotTemplate,
        $octopusUrl,
        $apiKey,
        $spaceId,
        $usingCaC
    )

    $runbookPackages = @()
    foreach ($package in $snapshotTemplate.Packages)
    {
        $packageVersion = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -spaceId $spaceId -endPoint "feeds/$($package.FeedId)/packages/versions?packageId=$($package.PackageId)&take=1" -method "Get" -item $null

        if ($packageVersion.TotalResults -le 0)
        {
            Write-Error "Unable to find a package version for $($package.PackageId).  This is required to create a new unpublished snapshot.  Exiting."
            exit 1
        }

        $runbookPackages += @{
            StepName = $package.StepName
            ActionName = $package.ActionName
            Version = $packageVersion.Items[0].Version
            PackageReferenceName = $package.PackageReferenceName
        }
        
    }

    return $runbookPackages
}

function Get-RunbookGitReferences
{
    param(
        $snapshotTemplate
    )

    $runbookReferences = @()
    foreach ($reference in $snapshotTemplate.SelectedGitResources)
    {        
        $gitReference = $reference.DefaultBranch
        if (($gitReference -contains "refs/heads/") -eq $false)
        {
            $gitReference = "refs/heads/$gitReference"
        }

        $runbookReferences += @{
            StepName = $reference.ActionName
            GitReferenceResource = @{
                GitRef = $gitReference
            }
            GitResourceReferenceName = ""            
        }
    }

    return $runbookReferences
}

function Get-ProjectSlug
{
    param
    (
        $runbookToRun,
        $projectToUse,
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    if ($null -ne $projectToUse)
    {
        return $projectToUse.Slug
    }

    $project = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -endPoint "projects/$($runbookToRun.ProjectId)" -method "GET" -item $null

    return $project.Slug
}

function Get-RunbookFormValues
{
    param (
        $runbookPreview,
        $runbookPromptedVariables        
    )

    $runbookFormValues = @{}

    if ([string]::IsNullOrWhiteSpace($runbookPromptedVariables) -eq $true)
    {
        return $runbookFormValues
    }    
    
    $promptedValueList = @(($runbookPromptedVariables -Split "`n").Trim())
    Write-OctopusInformation $promptedValueList.Length
    
    foreach($element in $runbookPreview.Form.Elements)
    {
    	$nameToSearchFor = $element.Control.Name
        $uniqueName = $element.Name
        $isRequired = $element.Control.Required
        
        $promptedVariablefound = $false
        
        Write-OctopusInformation "Looking for the prompted variable value for $nameToSearchFor"
    	foreach ($promptedValue in $promptedValueList)
        {
        	$splitValue = $promptedValue -Split "::"
            Write-OctopusInformation "Comparing $nameToSearchFor with provided prompted variable $($promptedValue[0])"
            if ($splitValue.Length -gt 1)
            {
            	if ($nameToSearchFor -eq $splitValue[0])
                {
                	Write-OctopusInformation "Found the prompted variable value $nameToSearchFor"
                	$runbookFormValues[$uniqueName] = $splitValue[1]
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

    return $runbookFormValues
}

function Invoke-OctopusDeployRunbook
{
    param (
        $runbookBody,
        $runbookWaitForFinish,
        $runbookCancelInSeconds,
        $projectNameForUrl,        
        $defaultUrl,
        $octopusApiKey,
        $spaceId,
        $parentTaskApprovers,
        $autoApproveRunbookRunManualInterventions,
        $parentProjectName,
        $parentReleaseNumber,
        $approvalEnvironmentName,
        $parentRunbookId,
        $parentTaskId,
        $usingCaC,
        $cacRunbookEndpoint,
        $runbookNameForUrl        
    )

    if ($usingCaC -eq $true)
    {
        $runbookResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -item $runbookBody -method "POST" -endPoint "$($cacRunbookEndpoint)/$runbookNameForUrl/run/v1"

        $runbookServerTaskId = $runBookResponse.Resources[0].TaskId
        Write-OctopusInformation "The task id of the new task is $runbookServerTaskId"

        $runbookRunId = $runbookResponse.Resources[0].Id
        Write-OctopusInformation "The runbook run id is $runbookRunId"            
    }
    else 
    {
        $runbookResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -item $runbookBody -method "POST" -endPoint "runbookRuns"

        $runbookServerTaskId = $runBookResponse.TaskId
        Write-OctopusInformation "The task id of the new task is $runbookServerTaskId"

        $runbookRunId = $runbookResponse.Id
        Write-OctopusInformation "The runbook run id is $runbookRunId"        
    }

    Write-OctopusSuccess "Runbook was successfully invoked, you can access the launched runbook [here]($defaultUrl/app#/$spaceId/tasks/$($runbookServerTaskId))"    
    
    if ($runbookWaitForFinish -eq $false)
    {
        Write-OctopusInformation "The wait for finish setting is set to no, exiting step"
        return
    }
    
    if ($null -ne $runbookBody.QueueTime)
    {
    	Write-OctopusInformation "The runbook queue time is set.  Exiting step"
        return
    }

    Write-OctopusSuccess "The setting to wait for completion was set, waiting until task has finished"
    $startTime = Get-Date
    $currentTime = Get-Date
    $dateDifference = $currentTime - $startTime
	
    $taskStatusUrl = "tasks/$runbookServerTaskId"
    $numberOfWaits = 0    
    
    While ($dateDifference.TotalSeconds -lt $runbookCancelInSeconds)
    {
        Write-OctopusInformation "Waiting 5 seconds to check status"
        Start-Sleep -Seconds 5
        $taskStatusResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -endPoint $taskStatusUrl -method "GET" -item $null
        $taskStatusResponseState = $taskStatusResponse.State

        if ($taskStatusResponseState -eq "Success")
        {
            Write-OctopusSuccess "The task has finished with a status of Success"
            exit 0            
        }
        elseif($taskStatusResponseState -eq "Failed" -or $taskStatusResponseState -eq "Canceled")
        {
            Write-OctopusSuccess "The task has finished with a status of $taskStatusResponseState status."
            exit 1            
        }
        elseif($taskStatusResponse.HasPendingInterruptions -eq $true)
        {
            if ($autoApproveRunbookRunManualInterventions -eq "Yes")
            {
                Submit-RunbookRunForAutoApproval -createdRunbookRun $createdRunbookRun -parentTaskApprovers $parentTaskApprovers -defaultUrl $DefaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -parentProjectName $parentProjectName -parentReleaseNumber $parentReleaseNumber -parentEnvironmentName $approvalEnvironmentName -parentRunbookId $parentRunbookId -parentTaskId $parentTaskId
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
        
        $numberOfWaits += 1
        if ($numberOfWaits -ge 10)
        {
        	Write-OctopusSuccess "The task state is currently $taskStatusResponseState"
        	$numberOfWaits = 0
        }
        else
        {
        	Write-OctopusInformation "The task state is currently $taskStatusResponseState"
        }  
        
        $startTime = $taskStatusResponse.StartTime
        if ($startTime -eq $null -or [string]::IsNullOrWhiteSpace($startTime) -eq $true)
        {        
        	Write-OctopusInformation "The task is still queued, let's wait a bit longer"
        	$startTime = Get-Date
        }
        $startTime = [DateTime]$startTime
        
        $currentTime = Get-Date
        $dateDifference = $currentTime - $startTime        
    }
    
    Write-OctopusSuccess "The cancel timeout has been reached, cancelling the runbook run"
    $cancelResponse = Invoke-RestMethod "$runbookBaseUrl/api/tasks/$runbookServerTaskId/cancel" -Headers $header -Method Post
    Write-OctopusSuccess "Exiting with an error code of 1 because we reached the timeout"
    exit 1
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
    
    $addOneDay = $false
    $textToParse = $futureDeploymentDate.ToLower()
    if ($textToParse -like "tomorrow*")
    {
    	Write-OctopusInformation "The future date $futureDeploymentDate supplied contains tomorrow, will add one day to whatever the parsed result is."
    	$addOneDay = $true
        $textToParse = $textToParse -replace "tomorrow", ""
    }
    
    [datetime]$outputDate = New-Object DateTime
    $currentDate = Get-Date
    $currentDate = $currentDate.AddMinutes(2)

    if ([datetime]::TryParse($textToParse, [ref]$outputDate) -eq $false)
    {
        Write-OctopusCritical "The suppplied date $textToParse cannot be parsed by DateTime.TryParse.  Please verify format and try again.  Please [refer to Microsoft's Documentation](https://docs.microsoft.com/en-us/dotnet/api/system.datetime.tryparse) on supported formats."
        exit 1
    }
    
    Write-OctopusInformation "The proposed date is $outputDate.  Checking to see if this will occur in the past."
    
    if ($addOneDay -eq $true)
    {
    	$outputDate = $outputDate.AddDays(1)
    	Write-OctopusInformation "The text supplied included tomorrow, adding one day.  The new proposed date is $outputDate."
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

function Get-RunbookSpecificMachines
{
    param (
        $defaultUrl,
        $octopusApiKey,    
        $runbookPreview,
        $runbookMachines,        
        $runbookRunName        
    )

    if ($runbookMachines -eq "N/A")
    {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($runbookMachines) -eq $true)
    {
        return @()
    }

    $translatedList = Get-MachineIdsFromMachineNames -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -targetMachines $runbookMachines

    $filteredList = @()    
    foreach ($runbookMachine in $translatedList)
    {    	
    	$runbookMachineId = $runbookMachine.Trim().ToLower()
    	Write-OctopusVerbose "Checking if $runbookMachineId is set to run on any of the runbook steps"
        
        foreach ($step in $runbookPreview.StepsToExecute)
        {
            foreach ($machine in $step.Machines)
            {
            	Write-OctopusVerbose "Checking if $runbookMachineId matches $($machine.Id) and it isn't already in the $($filteredList -join ",")"
                if ($runbookMachineId -eq $machine.Id.Trim().ToLower() -and $filteredList -notcontains $machine.Id)
                {
                	Write-OctopusInformation "Adding $($machine.Id) to the list"
                    $filteredList += $machine.Id
                }
            }
        }
    }

    if ($filteredList.Length -le 0)
    {
        Write-OctopusSuccess "The current task is targeting specific machines, but the runbook $runBookRunName does not run against any of these machines $runbookMachines. Skipping this run."
        exit 0
    }

    return $filteredList
}

function Get-ParentTaskApprovers
{
    param (
        $parentTaskId,
        $spaceId,
        $defaultUrl,
        $octopusApiKey
    )
    
    $approverList = @()
    if ($null -eq $parentTaskId)
    {
    	Write-OctopusInformation "The deployment task id to pull the approvers from is null, return an empty approver list"
    	return $approverList
    }

    Write-OctopusInformation "Getting all the events from the parent project"
    $parentEvents = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "events?regardingAny=$parentTaskId&spaces=$spaceId&includeSystem=true" -apiKey $octopusApiKey -method "GET"
    
    foreach ($parentEvent in $parentEvents.Items)
    {
        Write-OctopusVerbose "Checking $($parentEvent.Message) for manual intervention"
        if ($parentEvent.Message -like "Submitted interruption*")
        {
            Write-OctopusVerbose "The event $($parentEvent.Id) is a manual intervention approval event which was approved by $($parentEvent.Username)."

            $approverExists = $approverList | Where-Object {$_.Id -eq $parentEvent.UserId}        

            if ($null -eq $approverExists)
            {
                $approverInformation = @{
                    Id = $parentEvent.UserId;
                    Username = $parentEvent.Username;
                    Teams = @()
                }

                $approverInformation.Teams = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "teammembership?userId=$($approverInformation.Id)&spaces=$spaceId&includeSystem=true" -apiKey $octopusApiKey -method "GET"            

                Write-OctopusVerbose "Adding $($approverInformation.Id) to the approval list"
                $approverList += $approverInformation
            }        
        }
    }

    return $approverList
}

function Get-ApprovalTaskIdFromDeployment
{
    param (
        $parentReleaseId,
        $approvalEnvironment,
        $parentChannelId,    
        $parentEnvironmentId,
        $defaultUrl,
        $spaceId,
        $octopusApiKey 
    )

    $releaseDeploymentList = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "releases/$parentReleaseId/deployments" -method "GET" -apiKey $octopusApiKey -spaceId $spaceId
    
    $lastDeploymentTime = $(Get-Date).AddYears(-50)
    $approvalTaskId = $null
    foreach ($deployment in $releaseDeploymentList.Items)
    {
        if ($deployment.EnvironmentId -ne $approvalEnvironment.Id)
        {
            Write-OctopusInformation "The deployment $($deployment.Id) deployed to $($deployment.EnvironmentId) which doesn't match $($approvalEnvironment.Id)."
            continue
        }
        
        Write-OctopusInformation "The deployment $($deployment.Id) was deployed to the approval environment $($approvalEnvironment.Id)."

        $deploymentTask = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $null -endPoint "tasks/$($deployment.TaskId)" -apiKey $octopusApiKey -Method "Get"
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
        $lifecycle = Get-OctopusLifeCycle -channel $channelInformation -defaultUrl $defaultUrl -spaceId $spaceId -OctopusApiKey $octopusApiKey
        $lifecyclePhases = Get-LifecyclePhases -lifecycle $lifecycle -defaultUrl $defaultUrl -spaceId $spaceid -OctopusApiKey $octopusApiKey
        
        $foundDestinationFirst = $false
        $foundApprovalFirst = $false
        
        foreach ($phase in $lifecyclePhases.Phases)
        {
        	if ($phase.AutomaticDeploymentTargets -contains $parentEnvironmentId -or $phase.OptionalDeploymentTargets -contains $parentEnvironmentId)
            {
            	if ($foundApprovalFirst -eq $false)
                {
                	$foundDestinationFirst = $true
                }
            }
            
            if ($phase.AutomaticDeploymentTargets -contains $approvalEnvironment.Id -or $phase.OptionalDeploymentTargets -contains $approvalEnvironment.Id)
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

function Get-ApprovalTaskIdFromRunbook
{
    param (
        $parentRunbookId,
        $approvalEnvironment,
        $defaultUrl,
        $spaceId,
        $octopusApiKey 
    )
}

function Get-ApprovalTaskId
{
	param (
    	$autoApproveRunbookRunManualInterventions,
        $parentTaskId,
        $parentReleaseId,
        $parentRunbookId,
        $parentEnvironmentName,
        $approvalEnvironmentName,
        $parentChannelId,    
        $parentEnvironmentId,
        $defaultUrl,
        $spaceId,
        $octopusApiKey        
    )
    
    if ($autoApproveRunbookRunManualInterventions -eq $false)
    {
    	Write-OctopusInformation "Auto approvals are disabled, skipping pulling the approval deployment task id"
        return $null
    }
    
    if ([string]::IsNullOrWhiteSpace($approvalEnvironmentName) -eq $true)
    {
    	Write-OctopusInformation "Approval environment not supplied, using the current environment id for approvals."
        return $parentTaskId
    }
    
    if ($approvalEnvironmentName.ToLower().Trim() -eq $parentEnvironmentName.ToLower().Trim())
    {
        Write-OctopusInformation "The approval environment is the same as the current environment, using the current task id $parentTaskId"
        return $parentTaskId
    }
    
    $approvalEnvironment = Get-OctopusItemFromListEndpoint -itemNameToFind $approvalEnvironmentName -itemType "Environment" -defaultUrl $DefaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -defaultValue $null -endpoint "environments"
    
    if ([string]::IsNullOrWhiteSpace($parentReleaseId) -eq $false)
    {
        return Get-ApprovalTaskIdFromDeployment -parentReleaseId $parentReleaseId -approvalEnvironment $approvalEnvironment -parentChannelId $parentChannelId -parentEnvironmentId $parentEnvironmentId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId
    }

    return Get-ApprovalTaskIdFromRunbook -parentRunbookId $parentRunbookId -approvalEnvironment $approvalEnvironment -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey
}

function Get-OctopusLifecycle
{
    param (
        $channel,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    Write-OctopusInformation "Attempting to find the lifecycle information $($channel.Name)"
    if ($null -eq $channel.LifecycleId)
    {
        $lifecycleName = "Default Lifecycle"
        $lifecycleList = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "lifecycles?partialName=$([uri]::EscapeDataString($lifecycleName))&skip=0&take=1" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"
        $lifecycle = $lifecycleList.Items[0]
    }
    else
    {
        $lifecycle = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "lifecycles/$($channel.LifecycleId)" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"
    }

    Write-OctopusInformation "Successfully found the lifecycle $($lifecycle.Name) to use for this channel."

    return $lifecycle
}

function Get-LifecyclePhases
{
    param (
        $lifecycle,        
        $defaultUrl,
        $spaceId,
        $octopusApiKey
    )

    Write-OctopusInformation "Attempting to find the phase in the lifecycle $($lifecycle.Name) with the environment $environmentName to find the previous phase."
    if ($lifecycle.Phases.Count -eq 0)
    {
        Write-OctopusInformation "The lifecycle $($lifecycle.Name) has no set phases, calling the preview endpoint."
        $lifecyclePreview = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "lifecycles/$($lifecycle.Id)/preview" -spaceId $spaceId -apiKey $octopusApiKey -method "GET"
        $phases = $lifecyclePreview.Phases
    }
    else
    {
        Write-OctopusInformation "The lifecycle $($lifecycle.Name) has set phases, using those."
        $phases = $lifecycle.Phases    
    }

    Write-OctopusInformation "Found $($phases.Length) phases in this lifecycle."
    return $phases
}

function Submit-RunbookRunForAutoApproval
{
    param (
        $createdRunbookRun,
        $parentTaskApprovers,
        $defaultUrl,
        $octopusApiKey,
        $spaceId,
        $parentProjectName,
        $parentReleaseNumber,
        $parentRunbookId,
        $parentEnvironmentName,
        $parentTaskId        
    )

    Write-OctopusSuccess "The task has a pending manual intervention.  Checking parent approvals."    
    $manualInterventionInformation = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "interruptions?regarding=$($createdRunbookRun.TaskId)" -method "GET" -apiKey $octopusApiKey -spaceId $spaceId
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
        foreach ($approver in $parentTaskApprovers)
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
        	Write-OctopusSuccess "Matching approver found auto-approving."
            if ($manualIntervention.HasResponsibility -eq $false)
            {
                Write-OctopusInformation "Taking over responsibility for this manual intervention."
                $takeResponsiblilityResponse = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "interruptions/$($manualIntervention.Id)/responsible" -method "PUT" -apiKey $octopusApiKey -spaceId $spaceId
                Write-OctopusVerbose "Response from taking responsibility $($takeResponsiblilityResponse.Id)"
            }
            
            if ([string]::IsNullOrWhiteSpace($parentReleaseNumber) -eq $false)
            {
                $notes = "Auto-approving this runbook run.  Parent project $parentProjectName release $parentReleaseNumber to $parentEnvironmentName with the task id $parentTaskId was approved by $($automaticApprover.UserName).  That user is a member of one of the teams this manual intervention requires.  You can view that deployment $defaultUrl/app#/$spaceId/tasks/$parentTaskId"
            }
            else 
            {
                $notes = "Auto-approving this runbook run.  Parent project $parentProjectName runbook run $parentRunbookId to $parentEnvironmentName with the task id $parentTaskId was approved by $($automaticApprover.UserName).  That user is a member of one of the teams this manual intervention requires.  You can view that runbook run $defaultUrl/app#/$spaceId/tasks/$parentTaskId"
            }
            if ($runbookCustomNotesToggle -eq $true){
              $notes = $runbookCustomNotes
            }
            $submitApprovalBody = @{
                Instructions = $null;
                Notes = $notes
                Result = "Proceed"
            }
            $submitResult = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint "interruptions/$($manualIntervention.Id)/submit" -method "POST" -apiKey $octopusApiKey -item $submitApprovalBody -spaceId $spaceId
            Write-OctopusSuccess "Successfully auto approved the manual intervention $($submitResult.Id)"
        }
        else
        {
            Write-OctopusSuccess "Couldn't find an approver to auto-approve the child project.  Waiting until timeout or child project is approved."    
        }
    }
}

function Get-NonTenantedRunbookPreview
{
    param(
        $octopusUrl,
        $spaceId, 
        $apiKey,
        $runbookSnapShotIdToUse,
        $runbookEnvironmentId,
        $runbookToRun,
        $usingCaC,
        $cacRunbookEndPoint
    )

    $runbookPreview = $null

    try
    {
        $runbookPreviewEndpoint = "runbookSnapshots/$($runbookSnapShotIdToUse)/runbookRuns/preview/$($runbookEnvironmentId)?includeDisabledSteps=true"
        if ($usingCaC -eq $true)
        {
            Write-OctopusInformation "Using the CaC non-tenanted preview step"
    	    $runbookPreviewEndpoint = "$($cacRunbookEndPoint)/$($runbookToRun.Slug)/runbookRuns/preview/$($runbookEnvironmentId)?includeDisabledSteps=true"
        }        

        $runBookPreview = Invoke-OctopusApi -octopusUrl $octopusUrl -spaceId $spaceId -apiKey $apiKey -endPoint $runbookPreviewEndpoint -method "GET" -item $null
    	
    }
    catch
    {
    	Write-OctopusInformation "The current version of Octopus Deploy doesn't support Runbook Snapshot Preview"
    	$runBookPreview = Invoke-OctopusApi -octopusUrl $octopusUrl -spaceId $spaceId -apiKey $apiKey -endPoint "runbooks/$($runbookToRun.Id)/runbookRuns/preview/$($environmentToUse.Id)" -method "GET" -item $null
   	}

    return $runbookPreview
}

function Get-TenantedRunbookPreview 
{
    param(
        $octopusUrl,
        $spaceId, 
        $apiKey,
        $runbookSnapShotIdToUse,
        $runbookEnvironmentId,
        $runbookToRun,
        $tenantIdToUse,
        $usingCaC,
        $cacRunbookEndPoint
    )

    $runbookPreview = $null

    if ($usingCaC -eq $true)
    {
        Write-OctopusInformation "Using the CaC tenanted preview step that requires a POST instead of GET"        
        $runbookPreviewBody = @{
            DeploymentPreviews = @( 
                @{
                    EnvironmentId = $runbookEnvironmentId;
                    TenantId = $tenantIdToUse;
                }
            )
        }                     
                
        $runBookGroupedPreview = Invoke-OctopusApi -octopusUrl $octopusUrl -spaceId $spaceId -apiKey $apiKey -endPoint "$($runbookEndPoint)/$($runbookToRun.Slug)/runbookRuns/previews" -method "POST" -item $runbookPreviewBody 
        $runbookPreview = $runBookGroupedPreview[0]
    }
    else
    {
        $runBookPreview = Invoke-OctopusApi -octopusUrl $octopusUrl -spaceId $spaceId -apiKey $apiKey -endPoint "runbooks/$($runbookToRun.Id)/runbookRuns/preview/$($runbookEnvironmentId)/$($tenantIdToUse)" -method "GET"       
    }   

    return $runbookPreview
}
function Get-RunbookEndPoint
{
    param (        
        $cacBranchName,
        $projectToUse,
        $usingCaC
    )

    if ($usingCaC -eq $true)
    {
        return "projects/$($projectToUse.Id)/$([uri]::EscapeDataString($cacBranchName))/runbooks"        
    }
    else
    {
        return "projects/$($projectToUse.Id)/runbooks"
    }
}

function Get-IsProjectUsingCaCRunbooks
{
    param(
        $projectToUse
    )

    $hasPersistenceSettings = Get-Member -InputObject $projectToUse -Name "PersistenceSettings" -MemberType Properties
    if (!$hasPersistenceSettings)
    {
        return $false;        
    }

    Write-OctopusInformation "The project has the PersistenceSettings object."
    $hasConversionState = Get-Member -InputObject $projectToUse.PersistenceSettings -Name "ConversionState" -MemberType Properties        
    if (!$hasConversionState)
    {
        return $false;
    }

    Write-OctopusInformation "The project has the PersistenceSettings object."
    $hasRunbooksInGit = Get-Member -InputObject $projectToUse.PersistenceSettings.ConversionState -Name "RunbooksAreInGit" -MemberType Properties    
    
    if (!$hasRunbooksInGit)
    {
        return $false;
    }

    $isUsingCaC = $projectToUse.PersistenceSettings.ConversionState.RunbooksAreInGit    
    Write-OctopusInformation "The project is using CaC: $isUsingCaC"

    return $isUsingCaC
}

function Get-CaCBranchName
{
    param(
        $usingCac,
        $projectToUse,
        $providedBranchName
    )

    if ($usingCac -eq $false)
    {
        Write-OctopusInformation "The project isn't using CaC, so no need to pull the branch name"
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($providedBranchName) -eq $false)
    {
        if ($providedBranchName -like "refs/heads/*")
        {
            Write-OctopusInformation "The provided branch name is $providedBranchName, using that"
            return $providedBranchName
        }

        Write-OctopusInformation "The provided branch name $providedBranchName doesn't include refs/heads, adding it."
        return "refs/heads/$providedBranchName"
    }

    $returnedBranchName = "refs/heads/$($projectToUse.PersistenceSettings.DefaultBranch)"
    Write-OctopusInformation "The branch name wasn't provided, using the default branch name $returnedBranchName"
    return $returnedBranchName
}


$runbookWaitForFinish = GetCheckboxBoolean -Value $runbookWaitForFinish
$runbookUseGuidedFailure = GetCheckboxBoolean -Value $runbookUseGuidedFailure
$runbookUsePublishedSnapshot = GetCheckboxBoolean -Value $runbookUsePublishedSnapshot
$runbookCancelInSeconds = [int]$runbookCancelInSeconds

Write-OctopusInformation "Wait for Finish Before Check: $runbookWaitForFinish"
Write-OctopusInformation "Use Guided Failure Before Check: $runbookUseGuidedFailure"
Write-OctopusInformation "Use Published Snapshot Before Check: $runbookUsePublishedSnapshot"
Write-OctopusInformation "Runbook Name $runbookRunName"
Write-OctopusInformation "Runbook Base Url: $runbookBaseUrl"
Write-OctopusInformation "Runbook Space Name: $runbookSpaceName"
Write-OctopusInformation "Runbook Environment Name: $runbookEnvironmentName"
Write-OctopusInformation "Runbook Tenant Name: $runbookTenantName"
Write-OctopusInformation "Wait for Finish: $runbookWaitForFinish"
Write-OctopusInformation "Use Guided Failure: $runbookUseGuidedFailure"
Write-OctopusInformation "Cancel run in seconds: $runbookCancelInSeconds"
Write-OctopusInformation "Use Published Snapshot: $runbookUsePublishedSnapshot"
Write-OctopusInformation "Auto Approve Runbook Run Manual Interventions: $autoApproveRunbookRunManualInterventions"
Write-OctopusInformation "Auto Approve environment name to pull approvals from: $approvalEnvironmentName"

Write-OctopusInformation "Octopus runbook run machines: $runbookMachines"
Write-OctopusInformation "Parent Task Id: $parentTaskId"
Write-OctopusInformation "Parent Release Id: $parentReleaseId"
Write-OctopusInformation "Parent Channel Id: $parentChannelId"
Write-OctopusInformation "Parent Environment Id: $parentEnvironmentId"
Write-OctopusInformation "Parent Runbook Id: $parentRunbookId"
Write-OctopusInformation "Parent Environment Name: $parentEnvironmentName"
Write-OctopusInformation "Parent Release Number: $parentReleaseNumber"
Write-OctopusInformation "Parent Branch Name: $parentBranchName"

$verificationPassed = @()
$verificationPassed += Test-RequiredValues -variableToCheck $runbookRunName -variableName "Runbook Name"
$verificationPassed += Test-RequiredValues -variableToCheck $runbookBaseUrl -variableName "Base Url"
$verificationPassed += Test-RequiredValues -variableToCheck $runbookApiKey -variableName "Api Key"
$verificationPassed += Test-RequiredValues -variableToCheck $runbookEnvironmentName -variableName "Environment Name"

$projectVerificationPassed = Test-RequiredValues -variableToCheck $runbookProjectName -variableName "Project Name"
if ($projectVerificationPassed -eq $false)
{
    Write-OctopusCritical "Project Name previously wasn't required in earlier versions, but you need to include it now.  Without it, this step will find the first runbook that matches the name.  And it is required for CaC going forward.  Please add it to the step and try again."    
    $verificationPassed += $projectVerificationPassed
}

if ($verificationPassed -contains $false)
{
	Write-OctopusInformation "Required values missing"
	Exit 1
}

$runbookSpace = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookSpaceName -endpoint "spaces" -spaceId $null -octopusApiKey $runbookApiKey -defaultUrl $runbookBaseUrl -itemType "Space" -defaultValue $octopusSpaceId
$runbookSpaceId = $runbookSpace.Id

$projectToUse = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookProjectName -endpoint "projects" -spaceId $runbookSpaceId -defaultValue $null -itemType "Project" -octopusApiKey $runbookApiKey -defaultUrl $runbookBaseUrl

$usingCaC = Get-IsProjectUsingCaCRunbooks -projectToUse $projectToUse
$cacBranchName = Get-CaCBranchName -usingCac $usingCac -projectToUse $projectToUse -providedBranchName $parentBranchName
$runbookEndPoint = Get-RunbookEndPoint -cacBranchName $cacBranchName -projectToUse $projectToUse -usingCaC $usingCaC

$environmentToUse = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookEnvironmentName -itemType "Environment" -defaultUrl $runbookBaseUrl -spaceId $runbookSpaceId -octopusApiKey $runbookApiKey -defaultValue $null -endpoint "environments"

$runbookToRun = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookRunName -itemType "Runbook" -defaultUrl $runbookBaseUrl -spaceId $runbookSpaceId -endpoint $runbookEndPoint -octopusApiKey $runbookApiKey -defaultValue $null

if ($usingCaC -eq $false)
{
    $runbookSnapShotIdToUse = Get-RunbookSnapshotIdToRun -runbookToRun $runbookToRun -runbookUsePublishedSnapshot $runbookUsePublishedSnapshot -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $octopusSpaceId
    $projectNameForUrl = Get-ProjectSlug -projectToUse $projectToUse -runbookToRun $runbookToRun -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $runbookSpaceId
}
else
{
    $runbookSnapShotIdToUse = $null
    $projectNameForUrl = $projectToUse.Slug
}

$tenantToUse = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookTenantName -itemType "Tenant" -defaultValue $null -spaceId $runbookSpaceId -octopusApiKey $runbookApiKey -endpoint "tenants" -defaultUrl $runbookBaseUrl
if ($null -ne $tenantToUse)
{	
    $tenantIdToUse = $tenantToUse.Id
    $runbookPreview = Get-TenantedRunbookPreview -octopusUrl $runbookBaseUrl -spaceId $runbookSpaceId -apiKey $runbookApiKey -runbookSnapShotIdToUse $runbookSnapShotIdToUse -runbookEnvironmentId $environmentToUse.Id -runbookToRun $runbookToRun -tenantIdToUse $tenantToUse.Id -usingCaC $usingCaC -cacRunbookEndPoint $runbookEndPoint         
}
else
{
	$runbookPreview = Get-NonTenantedRunbookPreview -octopusUrl $runbookBaseUrl -spaceId $runbookSpaceId -apiKey $runbookApiKey -runbookSnapShotIdToUse $runbookSnapShotIdToUse -runbookEnvironmentId $environmentToUse.Id -runbookToRun $runbookToRun -usingCaC $usingCaC -cacRunbookEndPoint $runbookEndPoint
}

$childRunbookRunSpecificMachines = Get-RunbookSpecificMachines -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -runbookPreview $runBookPreview -runbookMachines $runbookMachines -runbookRunName $runbookRunName
$runbookFormValues = Get-RunbookFormValues -runbookPreview $runBookPreview -runbookPromptedVariables $runbookPromptedVariables

$queueDate = Get-QueueDate -futureDeploymentDate $runbookFutureDeploymentDate
$queueExpiryDate = Get-QueueExpiryDate -queueDate $queueDate

$approvalTaskId = Get-ApprovalTaskId -autoApproveRunbookRunManualInterventions $autoApproveRunbookRunManualInterventions -parentTaskId $parentTaskId -parentReleaseId $parentReleaseId -parentRunbookId $parentRunbookId -parentEnvironmentName $parentEnvironmentName -approvalEnvironmentName $approvalEnvironmentName -parentChannelId $parentChannelId -parentEnvironmentId $parentEnvironmentId -defaultUrl $runbookBaseUrl -spaceId $runbookSpaceId -octopusApiKey $runbookApiKey
$parentTaskApprovers = Get-ParentTaskApprovers -parentTaskId $approvalTaskId -spaceId $runbookSpaceId -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey

if ($usingCaC -eq $true)
{
    $snapshotTemplate = Invoke-OctopusApi -octopusUrl $runbookBaseUrl -apiKey $runbookApiKey -spaceId $runbookSpaceId -endPoint "$runbookEndPoint/$($runbookToRun.Slug)/runbookSnapShotTemplate" -method "Get"
    $selectedGitResources = @(Get-RunbookGitReferences -snapshotTemplate $snapshotTemplate)
    $selectedPackages = @(Get-RunbookPackages -snapshotTemplate $snapshotTemplate -octopusUrl $runbookBaseUrl -apiKey $runbookApiKey -spaceId $runbookSpaceId -usingCaC $usingCaC)

    $runbookBody = @{
        SelectedGitResources = $selectedGitResources;
        SelectedPackages = $selectedPackages;
        Runs= @(
            @{
                EnvironmentId = $($environmentToUse.Id);
                ExcludedMachineIds = @();                
                ForcePackageDownload = $false;
                FormValues = $runbookFormValues;
                QueueTime = $queueDate;
                QueueTimeExpiry = $queueExpiryDate;
                SpecificMachineIds = @($childRunbookRunSpecificMachines);
                SkipActions = @();
                TenantId = $tenantIdToUse;
                UseGuidedFailure = $runbookUseGuidedFailure;                
            }
        );                
    }

    Invoke-OctopusDeployRunbook -runbookBody $runbookBody -runbookWaitForFinish $runbookWaitForFinish -runbookCancelInSeconds $runbookCancelInSeconds -projectNameForUrl $projectNameForUrl -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $runbookSpaceId -parentTaskApprovers $parentTaskApprovers -autoApproveRunbookRunManualInterventions $autoApproveRunbookRunManualInterventions -parentProjectName $projectNameForUrl -parentReleaseNumber $parentReleaseNumber -approvalEnvironmentName $approvalEnvironmentName -parentRunbookId $parentRunbookId -parentTaskId $approvalTaskId -usingCaC $true -cacRunbookEndpoint $runbookEndPoint -runbookNameForUrl $runbookToRun.Slug
}
else
{
    $runbookBody = @{
        RunbookId = $($runbookToRun.Id);
        RunbookSnapShotId = $runbookSnapShotIdToUse;
        FrozenRunbookProcessId = $null;
        EnvironmentId = $($environmentToUse.Id);
        TenantId = $tenantIdToUse;
        SkipActions = @();
        QueueTime = $queueDate;
        QueueTimeExpiry = $queueExpiryDate;
        FormValues = $runbookFormValues;
        ForcePackageDownload = $false;
        ForcePackageRedeployment = $true;
        UseGuidedFailure = $runbookUseGuidedFailure;
        SpecificMachineIds = @($childRunbookRunSpecificMachines);
        ExcludedMachineIds = @()
    }
    
    Invoke-OctopusDeployRunbook -runbookBody $runbookBody -runbookWaitForFinish $runbookWaitForFinish -runbookCancelInSeconds $runbookCancelInSeconds -projectNameForUrl $projectNameForUrl -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $runbookSpaceId -parentTaskApprovers $parentTaskApprovers -autoApproveRunbookRunManualInterventions $autoApproveRunbookRunManualInterventions -parentProjectName $projectNameForUrl -parentReleaseNumber $parentReleaseNumber -approvalEnvironmentName $approvalEnvironmentName -parentRunbookId $parentRunbookId -parentTaskId $approvalTaskId
}