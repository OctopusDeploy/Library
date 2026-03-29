$project_source = $OctopusParameters["matlas-project-id"]
$cluster_source = $OctopusParameters["matlas-cluster-name"]
$retention_in_days = $OctopusParameters["matlas-retention-in-days"]
$snapshot_description = $OctopusParameters["matlas-snapshot-description"]
$check_delay_seconds = $OctopusParameters["matlas-check-delay-seconds"]

$login = $OctopusParameters["matlas-public-key"]
$secret = $OctopusParameters["matlas-private-key"]

$snapshot_description_json = $snapshot_description | ConvertTo-Json
$check_delay_seconds_nb = ($check_delay_seconds -as [int])
$retention_in_days_nb = ($retention_in_days -as [int])

function Check-Required($name, $value) {
	if($value -eq $null -or $value -eq ''){
    	Write-Error -Message "Missing parameter or invalid value for '$name'. ($value)" -ErrorAction Stop
    }
}

Check-Required 'matlas-public-key' $login
Check-Required 'matlas-private-key' $secret
Check-Required 'matlas-project-id' $project_source
Check-Required 'matlas-cluster-name' $cluster_source
Check-Required 'matlas-check-delay-seconds' $check_delay_seconds_nb
Check-Required 'matlas-retention-in-days' $retention_in_days_nb

Write-Host "Creating snapshot of $($project_source)/$($cluster_source) using $login."

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

$uri = New-Object System.Uri("$root/groups/$project_source/clusters/$cluster_source/backup/snapshots")
$request = "{`"description`": $snapshot_description_json, `"retentionInDays`": $retention_in_days_nb}"
$snapshot = Invoke-Api $uri "POST" $request

$uri = New-Object System.Uri("$root/groups/$project_source/clusters/$cluster_source/backup/snapshots/$($snapshot.id)")
while ($snapshot.status -eq "queued" -or $snapshot.status -eq "inProgress") {

	Write-Host "Waiting for snapshot to complete."	
	Start-Sleep -s $check_delay_seconds_nb
	$snapshot = Invoke-Api $uri "GET"
}

Write-Host "Snapshot $($snapshot.status). Id : '$($snapshot.id)'."

Set-OctopusVariable -name "matlas-snapshot-id" -value $snapshot.id
Set-OctopusVariable -name "matlas-snapshot-status" -value $snapshot.status
