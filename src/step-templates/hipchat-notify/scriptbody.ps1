#--------- Notify-Hipchat
$apitoken = $OctopusParameters['AuthToken']
$roomid = $OctopusParameters['RoomId']
$messageText = "(successful)"
$color = 'green'

if ($OctopusParameters['Octopus.Deployment.Error']) {
    $messageText = "(failed)"
    $color = 'red'
}

$messageValue = "$messageText $($OctopusParameters['Octopus.Project.Name']) [v$($OctopusParameters['Octopus.Release.Number'])] deployed to $($OctopusParameters['Octopus.Environment.Name'])    on $($OctopusParameters['Octopus.Machine.Name'])"

if ($OctopusParameters['NotificationText']) {
    $messageValue = $OctopusParameters['NotificationText']
    $color = $OctopusParameters['NotificationColor']
}

$message = New-Object PSObject 
$message | Add-Member -MemberType NoteProperty -Name color -Value $color
$message | Add-Member -MemberType NoteProperty -Name message -Value $messageValue
$message | Add-Member -MemberType NoteProperty -Name notify -Value $false
$message | Add-Member -MemberType NoteProperty -Name message_format -Value text

#Do the HTTP POST to HipChat
$uri = "https://api.hipchat.com/v2/room/$roomid/notification?auth_token=$apitoken"
$postBody = ConvertTo-Json -InputObject $message
$postStr = [System.Text.Encoding]::UTF8.GetBytes($postBody)

$webRequest = [System.Net.WebRequest]::Create($uri)
$webRequest.ContentType = "application/json"
$webrequest.ContentLength = $postStr.Length
$webRequest.Method = "POST"

$requestStream = $webRequest.GetRequestStream()
$requestStream.Write($postStr, 0,$postStr.length)
$requestStream.Close()

[System.Net.WebResponse] $resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()

[System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs
$sr.ReadToEnd()