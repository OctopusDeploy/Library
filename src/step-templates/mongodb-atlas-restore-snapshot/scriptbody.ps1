$project_source = $OctopusParameters["matlas-project-source"]
$cluster_source = $OctopusParameters["matlas-cluster-source"]
$project_target = $OctopusParameters["matlas-project-target"]
$cluster_target = $OctopusParameters["matlas-cluster-target"]
$check_delay_seconds = $OctopusParameters["matlas-check-delay-seconds"]

$login = $OctopusParameters["matlas-public-key"]
$secret = $OctopusParameters["matlas-private-key"]

$check_delay_seconds_nb = ($check_delay_seconds -as [int])

function Check-Required($name, $value) {
	if($value -eq $null -or $value -eq ''){
    	Write-Error -Message "Missing parameter or invalid value for '$name'. ($value)" -ErrorAction Stop
    }
}

Check-Required 'matlas-public-key' $login
Check-Required 'matlas-private-key' $secret
Check-Required 'matlas-project-source' $project_source
Check-Required 'matlas-cluster-source' $cluster_source
Check-Required 'matlas-project-target' $project_target
Check-Required 'matlas-cluster-target' $cluster_target
Check-Required 'matlas-check-delay-seconds' $check_delay_seconds_nb

Write-Host "Restoring from $($project_source)/$($cluster_source) to $($project_target)/$($cluster_target) using $login."

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
$uri = New-Object System.Uri("$root/groups/$project_source/clusters/$cluster_source/backup/snapshots?itemsPerPage=5")
$results = Invoke-Api $uri "GET"
$snapshots = $results.results | Where-Object { $_.status -eq "completed" }
$snapshot = $snapshots[0]

$uri = New-Object System.Uri("$root/groups/$project_source/clusters/$cluster_source/backup/restoreJobs")
$request = "{`"deliveryType`":`"automated`", `"snapshotId`":`"$($snapshot.id)`", `"targetClusterName`":`"$cluster_target`", `"targetGroupId`":`"$project_target`"}"
$job = Invoke-Api $uri "POST" $request

$uri = New-Object System.Uri("$root/groups/$project_source/clusters/$cluster_source/backup/restoreJobs/$($job.id)")
while ($null -eq $job.finishedAt -or $job.finishedAt -eq "") {

	Write-Host "Waiting for restore to complete."	
	Start-Sleep -s $check_delay_seconds_nb
	$job = Invoke-Api $uri "GET"
}

Write-Host "Restore completed."
