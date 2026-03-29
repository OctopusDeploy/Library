#-----------------------------
#Latest Update 2021-01-21
#Bilal Aljbour - FRISS
#-----------------------------
$url = "https://rest.messagebird.com/messages?access_key=$MessageBird_Key"
$params = @{
href = 'https://rest.messagebird.com/messages'
recipients = "$MessageBird_Recipients"
originator = "$MessageBird_originator"
body = "$MessageBird_body"
}
Invoke-WebRequest $url -Method Post -Body $params -UseBasicParsing | Out-Null
Write-Host 'Message has been sent!'