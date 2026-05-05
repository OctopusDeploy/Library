# Gather Octopus variables
$pagerDutyToken = $OctopusParameters['PagerDuty.API.AuthorizationToken']
$incidentTitle = $OctopusParameters['PagerDuty.Incident.Title']
$serviceId = $OctopusParameters['PagerDuty.Service.Id']
$incidentPriority = $OctopusParameters['PagerDuty.Priority.Code']
$incidentUrgency = $OctopusParameters['PagerDuty.Urgency.Code']
$escalationPolicyId = $OctopusParameters['PagerDuty.EscalationPolicy.Id']
$incidentDetails = $OctopusParameters['PagerDuty.Body.Details']
$pagerDutyFrom = "Octopus Deploy Project: $($OctopusParameters['Octopus.Project.Name']) Environment $($OctopusParameters['Octopus.Environment.Name'])"

# Configure request headers
$headers = @{
    "Authorization" = "Token token=$pagerDutyToken"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "From" = "$pagerDutyFrom"
}

# Build Incident Object
$incidentPayload = @{
  incident = @{
    type = "incident"
    title = $incidentTitle
    service = @{
      id = $serviceId
      type = "service_reference"
    }
  
    urgency = $incidentUrgency
    body = @{
      type = "incident_body"
      details = $incidentDetails
    }
  }
}

# Check to see if an escalation id was specified
if (![string]::IsNullOrWhitespace($escalationPolicyId))
{
  $policyDetails = @{
    type = "escalation_policy_reference"
    id = $escalationPolicyId
  }

  $incidentPayload.incident.Add("escalation_policy", $policyDetails)
}


# Get Priority
$priorities = (Invoke-RestMethod -Method Get -Uri "https://api.pagerduty.com/priorities" -Headers $headers)
$priority = ($priorities.priorities | Where-Object {$_.Name -eq $incidentPriority})

# Add priority to body
$priorityBody = @{
  id = "$($priority.id)"
  type = "priority_reference"
}
$incidentPayload.incident.Add("priority", $priorityBody)

# Submit incident
try
{
  $responseResult = Invoke-RestMethod -Method Post -Uri "https://api.pagerduty.com/incidents" -Body ($incidentPayload | ConvertTo-Json -Depth 10) -Headers $headers
  Write-Host "Successfully created incident."
  $responseResult.incident
}
catch [System.Exception] {
        Write-Host $_.Exception.Message
        
        $ResponseStream = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($ResponseStream)
        $Reader.ReadToEnd() | Write-Error
}