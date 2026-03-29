## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------
$pageId = $OctopusParameters['PageId']
$apiKey = $OctopusParameters['ApiKey']
$incidentName = $OctopusParameters['IncidentName']
$incidentStatus = $OctopusParameters['IncidentStatus']
$incidentMessage = $OctopusParameters['IncidentMessage']

function Validate-Parameter($parameterValue, $parameterName) {
    if(!$parameterName -contains "Key") {
        Write-Host "${parameterName}: ${parameterValue}"
    }

    if (! $parameterValue) {
        throw "$parameterName cannot be empty, please specify a value"
    }
}

function Get-InProgressScheduledIncidentByName
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PageId,

        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $url = "https://api.statuspage.io/v1/pages/$PageId/incidents/unresolved.json"
    $headers = @{"Authorization"="OAuth $ApiKey"}

    $response = iwr -UseBasicParsing -Uri $url -Headers $headers -Method GET
    $content = ConvertFrom-Json $response
    $incident = $content | where {$_.name -eq $Name}
    $incident.id
}

function Update-ScheduledIncident
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PageId,

        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        [string]$IncidentId,

        [Parameter(Mandatory=$true)]
        [ValidateSet("scheduled", "in_progress", "verifying", "completed")]
        [string]$Status,
        
        [Parameter(Mandatory=$false)]
        [string]$Message
    )

    $url = "https://api.statuspage.io/v1/pages/$PageId/incidents/$IncidentId.json"
    $headers = @{"Authorization"="OAuth $ApiKey"}
    $body = "incident[status]=$Status"

    if($Message)
    {
        $body += "&incident[message]=$Message"
    }

    $response = iwr -UseBasicParsing -Uri $url -Headers $headers -Method PATCH -Body $body -ContentType application/x-www-form-urlencoded
}

Validate-Parameter $pageId -parameterName 'PageId'
Validate-Parameter $apiKey = -parameterName 'ApiKey'
Validate-Parameter $incidentName = -parameterName 'IncidentName'
Validate-Parameter $incidentStatus -parameterName 'IncidentStatus'

$incidentId = Get-InProgressScheduledIncidentByName -PageId $pageId -ApiKey $apiKey -Name $incidentName
Write-Verbose "Found incident id: $incidentId"
Write-Output "Updating scheduled maintenance incident `"$incidentName`" [IncidentId: $incidentId]"
Update-ScheduledIncident -PageId $pageId -ApiKey $apiKey -IncidentId $incidentId -Status $incidentStatus -Message $incidentMessage 
