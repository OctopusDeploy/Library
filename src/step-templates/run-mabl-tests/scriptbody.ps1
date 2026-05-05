param(
    [string]$mablApiKey,
    [string]$mablEnvId,
    [string]$mablAppId,
    [string]$mablPlanLabels,
    [string]$mablBranch,
    [string]$mablAwaitCompletion
) 

$ErrorActionPreference = "Stop" 

# Constants
$PollSec = 10
$UserAgent = "mabl-octopus-plugin/0.0.3"
$ApiBase = "https://api.mabl.com"
$DeploymentEventsUri = "$ApiBase/events/deployment"
$ExecutionResultBaseUri = "$ApiBase/execution/result/event"

function Get-Param($Name, [switch]$Required, $MatchingPattern, $Explanation) {
    $result = $null

    if ($null -ne $OctopusParameters) {
        $result = $OctopusParameters[$Name]
    }

    if ($null -eq $result) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($null -ne $variable) {
            $result = $variable.Value
        }
    }

    if ($null -eq $result -or $result -eq "") {
        if ($Required) {
            throw "Missing parameter value $Name"
        }
    }

    if ($null -ne $result -and "" -ne $result -and $null -ne $MatchingPattern -and $result -notmatch $MatchingPattern) {
        throw "$Explanation"
    }

    return $result
}

function Write-Result($Result) {
    foreach ($execution in $Result.executions) {
        $planName = $execution.plan.name
        $planId = $execution.plan.id
        $planStatus = $execution.plan_execution.status
        $t = New-TimeSpan -seconds (($execution.stop_time - $execution.start_time) /  1000)
        $planTime = Get-Date -Hour $t.Hours -Minute $t.Minutes -Second $t.Seconds -UFormat "%T"

        Write-Host "Plan name: ${planName}, id: ${planId}, status: ${planStatus}, run time: ${planTime}"

        $tests = $execution.journeys
        $testExecutions = $execution.journey_executions

        foreach ($test in $tests) {
            $testId = $test.id
            $testName = $test.name

            foreach ($testExecution in $testExecutions) {
                if ($testExecution.journey_id -eq $testId) {
                    $t = New-TimeSpan -seconds (($testExecution.stop_time - $testExecution.start_time) / 1000)
                    $testTime = Get-Date -Hour $t.Hours -Minute $t.Minutes -Second $t.Seconds -UFormat "%T"
                    $testStatus = $testExecution.status
                    $testBrowser = $testExecution.browser_type
                    $testExecutionId = $testExecution.journey_execution_id
                    Write-Host "  Test name: ${testName}, id: ${testExecutionId}, status: ${testStatus}," `
                        "browser: ${testBrowser}, run time: ${testTime}"
                    break
                }
            }

        }
    }
}

& {
    param (
        [string]$mablApiKey,
        [string]$mablEnvId,
        [string]$mablAppId,
        [string]$mablPlanLabels,
        [string]$mablAwaitCompletion
    )

    $kv = "key:$($mablApiKey)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($kv))
    $basicAuthValue = "Basic $encodedCreds"
    $headers = @{
        Authorization = $basicAuthValue
        accept        = "application/json"
    }

    # Submit Deployment Event
    $resp = ""
    $eventId = ""
    try {
        $m = @{}
        if ($null -ne $mablEnvId -and "" -ne $mablEnvId) {
            $m.add("environment_id", $mablEnvId)
        }
        if ($null -ne $mablAppId -and "" -ne $mablAppId) {
            $m.add("application_id", $mablAppId)
        }
        if ($m.count -eq 0) {
            Write-Host "Either an environment ID or an application ID must be provided"
            exit 1
        }
        if ($null -ne $mablPlanLabels -and "" -ne $mablPlanLabels) {
            $planLabelArray = $mablPlanLabels.Split(",")
            $m.add("plan_labels", $planLabelArray)
        }
        if ($null -ne $mablBranch -and "" -ne $mablBranch) {
            $m.add("source_control_tag", $mablBranch)
        }
        $body = ConvertTo-Json -InputObject $m
        Write-Host "Creating Deployment..."
        $resp = Invoke-RestMethod -URI $DeploymentEventsUri -Method Post `
            -Headers $headers -ContentType 'application/json' `
            -UserAgent $UserAgent -Body $body

        $workspaceId = $resp.workspace_id
        $eventId = $resp.id
        Write-Host "View output at https://app.mabl.com/workspaces/${workspaceId}/events/${eventId}"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
    
        Write-Host "Failed to invoke deployment events API, status code: " `
            $statusCode " description: " `
            $_.Exception.Response.StatusDescription
    
        switch ($statusCode) {
            400 {
                Write-Host "At least one of environment ID or application ID must be specified"
                break
            }
            401 { 
                Write-Host "Invalid API key has been provided"
                break
            }
            403 {
                Write-Host "The provided API key is not authorized to submit deployment events"
                break
            }
            404 {
                Write-Host "The provided application or environment could not be found"
                break
            }
        }
        exit 1
    }


    # Poll Execution Result at least once based on await completion parameter
    $awaitCompletion = $mablAwaitCompletion -eq "True"
    $totalPlans = 0
    $passedPlans = 0
    $failedPlans = 0
    $totalTests = 0
    $passedTests = 0
    $failedTests = 0
    $execResult = ""
    try {
        $complete = -Not $awaitCompletion
        do {
            Start-Sleep -s $PollSec
            $eventId = $resp.id
            $uri = "$ExecutionResultBaseUri/$eventId"
            $execResult = Invoke-RestMethod -URI $uri -Method Get -Headers $headers
            $totalPlans = $execResult.plan_execution_metrics.total
            $passedPlans = $execResult.plan_execution_metrics.passed
            $failedPlans = $execResult.plan_execution_metrics.failed
            $totalTests = $execResult.journey_execution_metrics.total
            $passedTests = $execResult.journey_execution_metrics.passed
            $failedTests = $execResult.journey_execution_metrics.failed

            if ($passedPlans + $failedPlans -eq $totalPlans) {
                $complete = $TRUE
            }
            elseif (!$complete) {
                Write-Host "Plan runs" `
                    "[passed: $passedTests, failed: $failedTests, total: $totalTests]"
            }
        } while (!$complete)
    } 
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        Write-Host "Failed to invoke execution result API, status code:" `
            $statusCode " description: `
                " $_.Exception.Response.StatusDescription
    
        switch ($statusCode) {
            401 {
                Write-Host "Invalid API key has been provided"
                break
            }
            403 {
                Write-Host "The provided API key is not authorized to retrieve execution results"
                break
            }
            404 {
                Write-Host "The deployment event could not be found"
                break
            }
        }
    
        exit 1
    }

    if ($awaitCompletion) {
        # Display results
        Write-Host "Tests complete with status" `
            $(If ($execResult.event_status.succeeded) { "PASSED" } else { "FAILED"})
        Write-Result($execResult)

        If ($execResult.event_status.succeeded) { exit 0 } else { exit 1 }
    }

    Write-Host "Successfully triggered $totalPlans plan(s)"
    exit 0
} `
(Get-Param 'mablApiKey' -Required) `
(Get-Param 'mablEnvId' '-e$' 'Environment IDs must end with -e') `
(Get-Param 'mablAppId' '-a$' 'Application IDs must end with -a') `
(Get-Param 'mablPlanLabels') `
(Get-Param 'mablAwaitCompletion')
