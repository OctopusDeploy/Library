Set-StrictMode -Version Latest

function Send-VictorOpsAlert($url, $messageType, $entityDisplayName, $stateMessage, $customFields)
{
  $payload = @{
      "message_type" = $messageType
      "entity_display_name" = $entityDisplayName
      "state_message" = $stateMessage
  }

  if (-not ([string]::IsNullOrEmpty($customFields))) { 
    foreach($line in $customFields -split "`n") {
      if (-not ([string]::IsNullOrEmpty($line))) { 
        if ($line -like '*|*') {
          $kv = $line.Split('|')
          $payload.Add($kv[0], $kv[1])
        } else {
          write-verbose "The line '$line' in 'Custom fields' contained invalid data. Please ensure its a list of key value pairs, separated by '|'."
        }
      }
    }
  }

  write-verbose "Submitting payload`n$($payload | ConvertTo-Json)`n to $url"

  try {
    $response = Invoke-Restmethod -Method POST -Uri $url -Body ($payload | ConvertTo-Json) -ContentType "application/json"
    write-host "Successfully submitted"
    write-verbose "Response was `n$($response | ConvertTo-Json)"
  } catch {
    Fail-Step "Failed to submit VictorOps alert - $($_)"
  }

}

if (Test-Path variable:OctopusParameters) {
  if ([string]::IsNullOrEmpty($OctopusParameters['VictorOpsAlertUrl']))  {
  	Write-Host "Please provide the VictorOps Url"
    exit 1
  }
  if ([string]::IsNullOrEmpty($OctopusParameters['VictorOpsMessageType']))  {
  	Write-Host "Please provide a valid Message Type"
    exit 1
  }
  if ([string]::IsNullOrEmpty($OctopusParameters['VictorOpsEntityDisplayName']))  {
  	Write-Host "Please provide a valid Title"
    exit 1
  }
  if ([string]::IsNullOrEmpty($OctopusParameters['VictorOpsMessage']))  {
  	Write-Host "Please provide a valid Message"
    exit 1
  }
  Send-VictorOpsAlert -url $OctopusParameters['VictorOpsAlertUrl'] `
                      -messageType $OctopusParameters['VictorOpsMessageType'] `
                      -entityDisplayName $OctopusParameters['VictorOpsEntityDisplayName'] `
                      -stateMessage $OctopusParameters['VictorOpsMessage'] `
                      -customFields $OctopusParameters['VictorOpsCustomFields']
}