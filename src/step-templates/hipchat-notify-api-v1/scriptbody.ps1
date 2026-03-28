$message = if ($OctopusParameters['HipChatMessage']) { $OctopusParameters['HipChatMessage'] } else { "(successful) " + $OctopusParameters['Octopus.Project.Name'] + " [v$($OctopusParameters['Octopus.Release.Number'])] deployed to $($OctopusParameters['Octopus.Environment.Name'])  on $($OctopusParameters['Octopus.Machine.Name'])" } 
#---------
$apitoken = $OctopusParameters['HipChatAuthToken']
$roomid = $OctopusParameters['HipChatRoomId']
$from = $OctopusParameters['HipChatFrom']
$colour = $OctopusParameters['HipChatColor']

Try 
{
	#Do the HTTP POST to HipChat
	$post = "auth_token=$apitoken&room_id=$roomid&from=$from&color=$colour&message=$message&notify=1&message_format=text"
	$webRequest = [System.Net.WebRequest]::Create("https://api.hipchat.com/v1/rooms/message")
	$webRequest.ContentType = "application/x-www-form-urlencoded"
	$postStr = [System.Text.Encoding]::UTF8.GetBytes($post)
	$webrequest.ContentLength = $postStr.Length
	$webRequest.Method = "POST"
	$requestStream = $webRequest.GetRequestStream()
	$requestStream.Write($postStr, 0,$postStr.length)
	$requestStream.Close()
	
	[System.Net.WebResponse] $resp = $webRequest.GetResponse();
	$rs = $resp.GetResponseStream();
	[System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
	$sr.ReadToEnd();					
}
catch [Exception] {
	"Woah!, wasn't expecting to get this exception. `r`n $_.Exception.ToString()"
}