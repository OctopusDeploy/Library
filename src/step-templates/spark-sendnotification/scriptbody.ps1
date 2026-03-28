function send-sparkmessage
{
<#
	.SYNOPSIS
		Send a message to a spark user
	
	.DESCRIPTION
		A detailed description of the send-sparkmessagetouser function.
	
	.PARAMETER useremail
		user email
	
	.PARAMETER message
		Message to send to the user. Can use markdown.
	
	.PARAMETER auth_token
		OAuth token
	
	.PARAMETER api_uri
		API url if different from default (https://api.ciscospark.com/v1)
	
	.PARAMETER userid
		user id
	
	.PARAMETER proxy
		proxy url
	
	.PARAMETER roomid
		A description of the roomid parameter.
	
	.PARAMETER room_id
		Id for room to send message to.
	
	.NOTES
		Additional information about the function.
#>
	
	param
	(
		[Parameter(ParameterSetName = 'toPersonEmail',
				   Mandatory = $true,
				   HelpMessage = 'User email to contact')]
		[string]$useremail,
		[Parameter(Mandatory = $true,
				   HelpMessage = 'Set a message to send to the user. Can use markdown.')]
		[string]$message,
		[Parameter(Mandatory = $true,
				   HelpMessage = 'Set OAuth token')]
		[string]$auth_token,
		[Parameter(Mandatory = $false,
				   HelpMessage = 'API url if different from default.')]
		[uri]$api_uri = "https://api.ciscospark.com/v1",
		[Parameter(ParameterSetName = 'toPersonID',
				   Mandatory = $true)]
		[string]$userid,
		[string]$proxy,
		[Parameter(ParameterSetName = 'toRoomID',
				   Mandatory = $true)]
		[string]$roomid
	)
	
	$header = @{ 'Authorization' = " Bearer $auth_token" }
	
	switch ($PsCmdlet.ParameterSetName)
	{
		"toPersonEmail" {
			$body = @{
				toPersonEmail = $useremail
				markdown = $message
			}
		}
		"toPersonID" {
			$body = @{
				toPersonId = $userid
				markdown = $message
			}
		}
		"toRoomID"{
			$body = @{
				roomId = $roomid
				markdown = $message
			}
		}
		
	}
	
	if ($proxy)
	{
		Invoke-RestMethod -Uri "$api_uri/messages" -Method Post -headers $header -Body (ConvertTo-Json $body) -ContentType "application/json" -Proxy $proxy
	}
	else
	{
		Invoke-RestMethod -Uri "$api_uri/messages" -Method Post -headers $header -Body (ConvertTo-Json $body) -ContentType "application/json"
	}
}


$useremail = $OctopusParameters['useremail']
$message = $OctopusParameters['message']
$auth_token = $OctopusParameters['auth_token']
$proxy = $OctopusParameters['proxy']
$contactmethod = $OctopusParameters['contactmethod']
$contactdetails = $OctopusParameters['contactdetails']

Write-Verbose "contact details : $contactdetails"
Write-Verbose "contact method : $contactmethod"
Write-Verbose "message : $message"
Write-Verbose "proxy: $proxy"
foreach ($contactdetail in $contactdetails.Replace(" ", "").Split(","))
{
	switch ($contactmethod)
	{
		"useremail" {
			if ($proxy)
			{
				Write-Host "Sending Spark message via $contactmethod to $contactdetail"
				send-sparkmessage -useremail $contactdetail -message $message -auth_token $auth_token -proxy $proxy
			}
			else
			{
				Write-Host "Sending Spark message via $contactmethod to $contactdetail"
				send-sparkmessage -useremail $contactdetail -message $message -auth_token $auth_token
			}
		}
		
		
		"userid" {
			if ($proxy)
			{
				Write-Host "Sending Spark message via $contactmethod to $contactdetail"
				send-sparkmessage -userid $contactdetail -message $message -auth_token $auth_token -proxy $proxy
			}
			else
			{
				Write-Host "Sending Spark message via $contactmethod to $contactdetail"
				send-sparkmessage -userid $contactdetail -message $message -auth_token $auth_token
			}
		}
		
		"roomid"{
			if ($proxy)
			{
				Write-Host "Sending Spark message via $contactmethod to $contactdetail"
				send-sparkmessage -roomid $contactdetail -message $message -auth_token $auth_token -proxy $proxy
			}
			else
			{
				Write-Host "Sending Spark message via $contactmethod to $contactdetail"
				send-sparkmessage -roomid $contactdetail -message $message -auth_token $auth_token
			}
		}
	}
	
}
