$_WebHookUrl = $OctopusParameters['acpm_WebHookURL']
$_ContentPayload = $OctopusParameters['acpm_ContentPayload']
$_WarningOnFailure = [System.Convert]::ToBoolean($OctopusParameters['acpm_WarningOnFailure'])

try {
  #Encode the content message as JSON. ConvertTo-JSON adds quotes to the string.
  $_EncodedContentPayload = $_ContentPayload | ConvertTo-JSON

  #Create a JSON object that Chime wants
  #https://docs.aws.amazon.com/chime/latest/ug/webhooks.html
  $_JsonPayload = '{"Content":'
  $_JsonPayload += $_EncodedContentPayload
  $_JsonPayload += '}'

  Write-Host "Sending message to webhook."
  Write-Host "------ Message ------"
  Write-Host "$_ContentPayload"
  Write-Host "---- End Message ----"
	
  #Make the request and send the payload
  Invoke-WebRequest "$_WebHookUrl" -UseBasicParsing -ContentType "application/json" -Method POST -Body $_JsonPayload | Out-Null
  Write-Host "Message successfully sent to webhook."
}
catch {
  #If WarningOnFailure is not true, then write an error and fail the deployment.
  if($_WarningOnFailure -eq $false) {
    Write-Error "Could not send message to Chime web hook."
    if(!([string]::IsNullOrEmpty($_.Exception.Message))) {
      Write-Error "Exception Message: $($_.Exception.Message)"
    }
  }
  #Else, just write a warning and continue on.
  else {
    Write-Warning "Could not send message to Chime web hook."
    if(!([string]::IsNullOrEmpty($_.Exception.Message))) {
      Write-Warning "Exception Message: $($_.Exception.Message)"
    }
  }
}