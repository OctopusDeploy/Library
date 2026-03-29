## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------
$pageId = $OctopusParameters['PageId']
$apiKey = $OctopusParameters['ApiKey']
$incidentName = $OctopusParameters['IncidentName']
$incidentStatus = $OctopusParameters['IncidentStatus']
$incidentMessage = $OctopusParameters['IncidentMessage']
$componentId = $OctopusParameters['ComponentId']

function Validate-Parameter($parameterValue, $parameterName) {
    if(!$parameterName -contains "Key") {
        Write-Host "${parameterName}: ${parameterValue}"
    }

    if (! $parameterValue) {
        throw "$parameterName cannot be empty, please specify a value"
    }
}

function New-ScheduledIncident
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PageId,

        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet("scheduled", "in_progress", "verifying", "completed")]
        [string]$Status,
        
        [Parameter(Mandatory=$false)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$Componentid
    )

    $date = [System.DateTime]::Now.ToString("o")
    $dateTomorrow = [System.DateTime]::Now.AddDays(1).ToString("o")
    $url = "https://api.statuspage.io/v1/pages/$PageId/incidents.json"
    $headers = @{"Authorization"="OAuth $ApiKey"}
    $body = "incident[name]=$Name&incident[status]=$Status&incident[scheduled_for]=$date&incident[scheduled_until]=$dateTomorrow"

    if($Message)
    {
        $body += "&incident[message]=$Message"
    }

    if($Componentid)
    {
        $body += "&incident[component_ids][]=$Componentid"
    }

    $response = iwr -UseBasicParsing -Uri $url -Headers $headers -Method POST -Body $body
    $content = ConvertFrom-Json $response
    $content.id
}

Validate-Parameter $pageId -parameterName 'PageId'
Validate-Parameter $apiKey = -parameterName 'ApiKey'
Validate-Parameter $incidentName = -parameterName 'IncidentName'
Validate-Parameter $incidentStatus -parameterName 'IncidentStatus'

Write-Output "Creating new scheduled maintenance incident `"$incidentName`" ..."
New-ScheduledIncident -PageId $pageId -ApiKey $apiKey -Name $incidentName -Status $incidentStatus -Message $incidentMessage -ComponentId $componentId
