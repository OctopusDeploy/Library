$url = "https://api.twilio.com/2010-04-01/Accounts/$Twilio_SendMessage_AccountSID/Messages.json"
$params = @{
    To = $Twilio_SendMessage_ToNumber;
    From = $Twilio_SendMessage_FromNumber;
    Body = $Twilio_SendMessage_Message
}

Write-Verbose "Creating Twilio credentials"
$secureToken = $Twilio_SendMessage_AuthToken | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Twilio_SendMessage_AccountSID, $secureToken)

Write-Verbose "Creating Twilio credentials"
Invoke-WebRequest $url -Method Post -Credential $credential -Body $params -UseBasicParsing
