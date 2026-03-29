$cluster = $OctopusParameters["matlas-cluster-name"]
$project = $OctopusParameters["matlas-project-id"]
$check_delay_seconds = $OctopusParameters["matlas-check-delay-seconds"]

$login = $OctopusParameters["matlas-public-key"]
$secret = $OctopusParameters["matlas-private-key"]

$pause = [System.Convert]::ToBoolean($OctopusParameters["matlas-pause"])
$check_delay_seconds_nb = ($check_delay_seconds -as [int])

function Check-Required($name, $value) {
	if($value -eq $null -or $value -eq ''){
    	Write-Error -Message "Missing parameter or invalid value for '$name'. ($value)" -ErrorAction Stop
    }
}

Check-Required 'matlas-public-key' $login
Check-Required 'matlas-private-key' $secret
Check-Required 'matlas-project-id' $project
Check-Required 'matlas-cluster-name' $cluster
Check-Required 'matlas-check-delay-seconds' $check_delay_seconds_nb

$action = "Pausing"
if($pause -eq $false){
	$action = "Resuming"
}

Write-Host "$action $($project)/$($cluster) using $login."

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-Api($uri, $method, $content) {

	$securedPassword = ConvertTo-SecureString -String $secret -AsPlainText -Force	
	$credentials = New-Object System.Management.Automation.PSCredential ($login, $securedPassword)

	try {
		return Invoke-RestMethod -Uri $uri -Method $method -Credential $credentials -ContentType "application/json" -Body $content
	}
	catch {
		Write-Error -Message $_ -ErrorAction Stop
	}
}


$root = "https://cloud.mongodb.com/api/atlas/v1.0"
$uri = New-Object System.Uri("$root/groups/$project/clusters/$cluster")
$data = Invoke-Api $uri "GET"

if ($data.paused -ne $pause) {	
	$value = $pause.ToString().ToLower()
	$data = Invoke-Api $uri "PATCH" "{`"paused`": $value}"	
	
	while ($data.stateName -eq "REPAIRING" -or $data.stateName -eq "UPDATING") {

		Write-Host "Waiting for change to be applied. Cluster status : $($data.stateName)."		
		Start-Sleep -s $check_delay_seconds_nb	
		$data = Invoke-Api $uri "GET"
	}	

	Write-Host "Change applied. $Cluster status : $($data.stateName)."
}
else {
	
	$action = If ($pause) { "paused" } Else { "running" }
	Write-Host "Cluster already $action, no change applied. $Cluster status : $($data.stateName)."
}
