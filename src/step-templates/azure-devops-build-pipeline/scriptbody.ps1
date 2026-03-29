$AzureDevOpsAccessKey = $AzureDevOpsAccessKey
$AzureDevOpsOrganizationName = $AzureDevOpsOrganizationName
$AzureDevOpsProjectName = $AzureDevOpsProjectName
$AzureDevOpsPipelineName = $AzureDevOpsPipelineName
$AzureDevOpsBranch = $AzureDevOpsBranch
$AzureDevOpsWaitUntilCompletion = $AzureDevOpsWaitUntilCompletion
$AzureDevOpsVariables = $AzureDevOpsVariables

function Test-RequiredValues
{
	param (
    	[PSVariable]$variableToCheck
    )
    if ([string]::IsNullOrWhiteSpace($variableToCheck.Value) -eq $true)
    {
    	Write-Host "$($variableToCheck.Name) is required."
        return $false
    }
    return $true
}
function Get-BuildPipelineId 
{
    param (
        $defaultUrl,
        $pipeline
    )
    try {
        Write-Host "Getting list of available pipelines"
        $url = "$defaultUrl/_apis/pipelines?api-version=6.0-preview.1"
        $pipelines = Invoke-RestMethod -Uri $url -Method GET -Headers $azureDevOpsAuthenticationHeader
        if([string]::IsNullOrWhiteSpace($pipelines) -eq $true)
        {
            Write-Error "Couldn't find any pipelines in $AzureDevOpsPipelineName"
            Exit 1
        }
        $pipelineId = ($pipelines.value | Where-Object {$_.name -eq $pipeline}).id
        if([string]::IsNullOrWhiteSpace($pipelineId) -eq $true)
        {
            Write-Error "Found ${$pipelines.count} pipelines in project $AzureDevOpsProjectName but couldn't find $AzureDevOpsPipelineName"
            Exit 1
        }
        return $pipelineId
    }
    catch 
    {
        Write-Error "An error occurred while getting the pipelines:`n$($_.Exception.Message)"
        Exit 1
    }
}
function Invoke-BuildPipeline 
{
    param (
        $defaultUrl,
        $pipelineId,
        $body
    )
    try {
        $url = "$defaultUrl/_apis/pipelines/$pipelineId/runs?api-version=6.0-preview.1"
        $pipeline = Invoke-RestMethod -Uri $url -Body $body -ContentType "application/json" -Method POST -Headers $azureDevOpsAuthenticationHeader
        return $pipeline       
    }
    catch {
        Write-Error "An error occurred while invoking the pipeline:`n$($_.Exception.Message)"
        Exit 1
    }    
}
function Get-BuildPipelineStatus 
{
    param (
        $defaultUrl,
        $pipelineId,
        $runId
    )
    try {
        $url = "$defaultUrl/_apis/pipelines/$pipelineId/runs/$($runId)?api-version=6.0-preview.1"
        return Invoke-RestMethod -Uri $url -Method GET -Headers $azureDevOpsAuthenticationHeader
    }
    catch {
        Write-Error "An error occurred while getting the pipeline status:`n$($_.Exception.Message)"
        Exit 1
    }  
}
$verificationPassed = @()
$verificationPassed += Test-RequiredValues -variableToCheck (Get-Variable AzureDevOpsAccessKey)
$verificationPassed += Test-RequiredValues -variableToCheck (Get-Variable AzureDevOpsOrganizationName)
$verificationPassed += Test-RequiredValues -variableToCheck (Get-Variable AzureDevOpsProjectName) 
$verificationPassed += Test-RequiredValues -variableToCheck (Get-Variable AzureDevOpsPipelineName)
$verificationPassed += Test-RequiredValues -variableToCheck (Get-Variable AzureDevOpsBranch)

if ($verificationPassed -contains $false)
{
	Write-Error "Required values missing. Please see output for further details."
	Exit 1
}

$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsAccessKey)")) }

Write-Host "Azure DevOps Organization Name: $AzureDevOpsOrganizationName"
Write-Host "Azure DevOps Project Name: $AzureDevOpsProjectName"
Write-Host "Azure DevOps Pipeline Name: $AzureDevOpsPipelineName"
Write-Host "Azure DevOps Branch: $AzureDevOpsBranch"
Write-Host "Azure DevOps Wait Until Completion: $AzureDevOpsWaitUntilCompletion"

$defaultUrl = "https://dev.azure.com/$AzureDevOpsOrganizationName/$AzureDevOpsProjectName"

$buildPipelineId = Get-BuildPipelineId -defaultUrl $defaultUrl -pipeline $AzureDevOpsPipelineName

$body = @"
{
    "resources": {
      "repositories": {
        "self": {
          "refName": "refs/heads/$AzureDevOpsBranch"
        }
      }
    },
    "variables": {
        $AzureDevOpsVariables
    }
  }
"@

$run = Invoke-BuildPipeline -defaultUrl $defaultUrl -pipelineId $buildPipelineId -body $body

Write-Highlight "The pipeline was successfully invoked, you can access the pipeline [here]($($run._links.web.href))."

if ($run.state -ne "completed" -and $AzureDevOpsWaitUntilCompletion -eq $true)
{
    do 
    {
        Write-Host "Waiting for pipeline completion..."
        Start-Sleep 30
        $status = Get-BuildPipelineStatus -defaultUrl $defaultUrl -pipelineId $buildPipelineId -runId $run.id
        Write-Host "Current Status: $($status.state)"
    }
    while ($status.state -ne "completed") 
    if ($status.result -ne "succeeded")
    {
        Write-Error "The Azure DevOps pipeline failed to complete successfully"
        Exit 1
    }
}
else 
{
   Write-Host "Azure DevOps pipeline status unknown. Update process to wait until completion for status updates."
}