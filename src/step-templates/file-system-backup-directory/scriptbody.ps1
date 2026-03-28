function Get-Stamped-Destination($BackupDestination) {
	$stampedFolderName = get-date -format "yyyy-MM-dd"
	$count = 1
	$stampedDestination = Join-Path $BackupDestination $stampedFolderName
	while(Test-Path $stampedDestination) {
		$count++
		$stamped = $stampedFolderName + "(" + $count + ")"
		$stampedDestination = Join-Path $BackupDestination $stamped
	}
	return $stampedDestination
}

$BackupSource = $OctopusParameters['BackupSource']
$BackupDestination = $OctopusParameters['BackupDestination']
$CreateStampedBackupFolder = $OctopusParameters['CreateStampedBackupFolder']
if($CreateStampedBackupFolder -like "True" ) {
	$BackupDestination = get-stamped-destination $BackupDestination
}

$options = $OctopusParameters['Options'] -split "\s+"

if(Test-Path -Path $BackupSource) {
    robocopy $BackupSource $BackupDestination $options
}

if($LastExitCode -gt 8) {
    exit 1
}
else {
    exit 0
}
