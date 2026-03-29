$sourceName = $OctopusParameters["EventSourceName"]
$logName = $OctopusParameters["EventLogName"]

$sourceExists = [System.Diagnostics.EventLog]::SourceExists($sourceName)
if($sourceExists) {
	Write-Output "Event source $sourceName already exist."
	return
}

[System.Diagnostics.EventLog]::CreateEventSource($sourceName, $logName)