$ErrorActionPreference = 'Stop'

Add-Type -Path "${MicroChap}\MicroCHAP.dll"

Function Sync-Unicorn {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$ControlPanelUrl,

		[Parameter(Mandatory=$True)]
		[string]$SharedSecret,

		[Parameter(Mandatory=$True)]
		[string[]]$Configurations,

		[string]$Verb = 'Sync'
	)

	# PARSE THE URL TO REQUEST
	$parsedConfigurations = ($Configurations) -join "^"

	$url = "{0}?verb={1}&configuration={2}" -f $ControlPanelUrl, $Verb, $parsedConfigurations

	Write-Host "Sync-Unicorn: Preparing authorization for $url"

	# GET AN AUTH CHALLENGE
	$challenge = Get-Challenge -ControlPanelUrl $ControlPanelUrl

	Write-Host "Sync-Unicorn: Received challenge: $challenge"

	# CREATE A SIGNATURE WITH THE SHARED SECRET AND CHALLENGE
	$signatureService = New-Object MicroCHAP.SignatureService -ArgumentList $SharedSecret

	$signature = $signatureService.CreateSignature($challenge, $url, $null)

	Write-Host "Sync-Unicorn: Created signature $signature, executing $Verb..."

	# USING THE SIGNATURE, EXECUTE UNICORN
	$result = Invoke-WebRequest -Uri $url -Headers @{ "X-MC-MAC" = $signature; "X-MC-Nonce" = $challenge } -TimeoutSec 10800 -UseBasicParsing

	$result.Content
}

Function Get-Challenge {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$ControlPanelUrl
	)

	$url = "$($ControlPanelUrl)?verb=Challenge"

	$result = Invoke-WebRequest -Uri $url -TimeoutSec 360 -UseBasicParsing

	$result.Content
}

$configs = $Configurations.split("`n")
Sync-Unicorn -ControlPanelUrl "$($SiteUrl)/unicorn.aspx" -SharedSecret $SharedSecret -Configurations $configs
