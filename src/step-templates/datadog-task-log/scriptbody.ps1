  
function Send-DatadogEvent (
    $datadog,
    [string] $text,
    [string] $level,
    $properties = @{},
    [string] $exception = $null,
    [switch] $template) {
    
    
    if (-not $level) {
        $level = 'Information'
    }

    if (@('Verbose', 'Debug', 'Information', 'Warning', 'Error', 'Fatal') -notcontains $level) {
        $level = 'Information'
    }


    $ddtags = "project:$($properties.ProjectName),deploymentname:$($properties.DeploymentName),env:$($properties.EnvironmentName)"
    if ($properties["TaskType"] -eq "Runbook") {
        $ddtags += ",runbookname:$($properties.RunbookName),tasktype:runbook"
    }
    else {
        $ddtags += ",tasktype:deployment"    
    }

    $body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $body.Add("ddsource", "Octopus Deploy")
    $body.Add("ddtags", $ddtags)
    $body.Add("service", $DatadogServiceName)
    $body.Add("hostname", "https://octopus.the-crock.com/")
    $body.Add("http.url", "$($properties["TaskLink"])")
    $body.Add("octopus.deployment.properties", "$($properties | ConvertTo-Json)")

    if ($exception) {
        $body.Add("error.message", "$($properties["Error"])")
        $body.Add("error.stack", "$($exception)")
    }
    
    $body.Add("level", "$($level)")
  
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("DD-APPLICATION-KEY", "$($DatadogApplicationKey)")
    $headers.Add("DD-API-KEY", "$($DatadogApiKey)")

    Invoke-RestMethod -Uri $DatadogUrl -Body $($body | ConvertTo-Json)  -ContentType "application/json" -Method POST -Headers $headers
}

function Set-ErrorDetails(){

    $octopusAPIHeader = @{ "X-Octopus-ApiKey" = $DatadogOctopusAPIKey }
    $taskDetailUri = "$($OctopusParameters['Octopus.Web.ServerUri'])/api/tasks/$($OctopusParameters["Octopus.Task.Id"])/details"

    $taskDetails = Invoke-RestMethod -Method Get -Uri $taskDetailUri -Headers $octopusAPIHeader 
    $errorMessage = "";
    $errorFirstLine = "";
    $isFirstLine = $true;

    foreach ($activityLog in $taskDetails.ActivityLogs) {
        foreach ($activityLogChild1 in $activityLog.Children) {
            foreach ($activityLogChild2 in $activityLogChild1.Children) {
                foreach ($logElement in $activityLogChild2.LogElements) {
                    if ($logElement.Category -eq "Error") {
                        if ($isFirstLine -eq $true) {
                            $errorFirstLine = $logElement.MessageText;
                            $isFirstLine = $false;
                        }

                        $errorMessage += $logElement.MessageText + " `n"
                    }
                }
            }
        }
    }

    $exInfo = @{
        firstLine = $errorFirstLine
        message = $errorMessage
    }

    return $exInfo;
}

function Set-TaskProperties(){
    $taskProperties = @{
        ProjectName     = $OctopusParameters['Octopus.Project.Name'];
        Result          = "succeeded";
        InstanceUrl     = $OctopusParameters['Octopus.Web.ServerUri'];
        EnvironmentName = $OctopusParameters['Octopus.Environment.Name'];
        DeploymentName  = $OctopusParameters['Octopus.Deployment.Name'];
        TenantName      = $OctopusParameters["Octopus.Deployment.Tenant.Name"]
        TaskLink        = $taskLink
    }
    
    if ([string]::IsNullOrEmpty($OctopusParameters["Octopus.Runbook.Id"]) -eq $false) {
        $taskProperties["TaskType"] 			= "Runbook"
        $taskProperties["RunbookSnapshotName"] 	= $OctopusParameters["Octopus.RunbookSnapshot.Name"]
        $taskProperties["RunbookName"]         	= $OctopusParameters["Octopus.Runbook.Name"]
    }
    else {
        $taskProperties["TaskType"] 		= "Deployment"
        $taskProperties["ReleaseNumber"] 	= $OctopusParameters['Octopus.Release.Number'];
        $taskProperties["Channel"]  		= $OctopusParameters['Octopus.Release.Channel.Name'];
    }

    return $taskProperties;
}

#******************************************************************

$taskLink = $OctopusParameters['Octopus.Web.ServerUri'] + "/app#/" + $OctopusParameters["Octopus.Space.Id"] + "/tasks/" + $OctopusParameters["Octopus.Task.Id"]
$level = "Information"
$exception = $null

Write-Output "Logging the deployment result to Datadog at $DatadogServerUrl..."

$properties = Set-TaskProperties

if ($OctopusParameters['Octopus.Deployment.Error']) {
    $exceptionInfo = Set-ErrorDetails
    $properties["Result"] = "failed"
    $properties["Error"] = $exceptionInfo["firstLine"]
    $exception = $exceptionInfo["message"]
    $level = "Error"
}

try {
    Send-DatadogEvent $datadog "A deployment of $($properties.ProjectName) release $($properties.ReleaseNumber) $($properties.Result) in $($properties.EnvironmentName)" -level $level -template -properties $properties -exception $exception
}
catch [Exception] {
    Write-Error "Unable to write task details to Datadog"
    $_.Exception | format-list -force
}
