$exportPath = $OctopusParameters["Redgate.Oracle.ExportPath"]
$server = $OctopusParameters["Redgate.Oracle.Server"]
$user = $OctopusParameters["Redgate.Oracle.Username"]
$password = $OctopusParameters["Redgate.Oracle.Password"]
$oracleTools = $OctopusParameters["Redgate.Oracle.InstallPath"]
$deploymentSchema = $OctopusParameters["Redgate.Oracle.DeploymentSchema"]
$sourceSchema = $OctopusParameters["Redgate.Oracle.SourceSchema"]
$packageInstallDirectory = $OctopusParameters["Octopus.Action.Package.InstallationDirectoryPath"]
$excludeOptions = $OctopusParameters["Redgate.Oracle.ExcludeOptions"]
$behaviorOptions = $OctopusParameters["Redgate.Oracle.BehaviorOptions"]
$ignoreOptions = $OctopusParameters["Redgate.Oracle.IgnoreOptions"]
$storageOptions = $OctopusParameters["Redgate.Oracle.StorageOptions"]
$excludeDependencies = $OctopusParameters["Redgate.Oracle.ExcludeDependencies"]
$filterPath = $OctopusParameters["Redgate.Oracle.FilterPath"]
$includeIdentical = $OctopusParameters["Redgate.Oracle.IncludeIdentical"]

Write-Host "Export Path: $exportPath"
Write-Host "Oracle Server: $server"
Write-Host "Oracle Username: $user"
Write-Host "Oracle Password not shown"
Write-Host "Oracle Source Schema: $sourceSchema"
Write-Host "Oracle Deployment Schema: $deploymentSchema"
Write-Host "Oracle Toolbelt Install Path: $oracleTools"
Write-Host "Package Install Directory: $packageInstallDirectory"
Write-Host "Filter Path: $filterPath"
Write-Host "Behavior Options: $behaviorOptions"
Write-Host "Exclude Options: $excludeOptions"
Write-Host "Exclude Dependencies: $excludeDependencies"
Write-Host "Ignore Options: $ignoreOptions"
Write-Host "Storage Options: $storageOptions"
Write-Host "Include Identical: $includeIdentical"

$sourceFolder = "$packageInstallDirectory\{$sourceSchema}"
Write-Host "Source Folder: $sourceFolder"

$maskedConnectionString = "$user/*****@$server{$deploymentSchema}"
$unmaskedConnectionString = "$user/$password@$server{$deploymentSchema}"
Write-Host "Creating a delta script by connecting to: $maskedConnectionString"

$oracleToolsSearchPath = "$oracleTools\**\SCO.exe"
$scoexeOptions = Get-ChildItem -Path $oracleToolsSearchPath | Sort-Object [Version] -Descending

if ($scoexeOptions -eq $null){
    Write-Error "Unable to find Oracle Schema Compare, please verify it is installed in the directory specified"
}
 
$schemaCompareExe = $scoexeOptions[0]
Write-Host "Running the exe $schemaCompareExe"

$deltaReportPath = "$exportPath\Changes.html"
Write-Host "Creating the delta report $deltaReportPath"

$changeScript = "$exportPath\Update.sql"
Write-Host "The change script is set to $changeScript"

$AllArgs = @(
	"/source:`"$sourceFolder`"", 
    "/target:`"$unmaskedConnectionString`"",
    "/scriptfile:`"$changeScript`"",
    "/report:`"$deltaReportPath`"", 
    "/reporttype:Simple")

if ([string]::IsNullOrWhiteSpace($behaviorOptions) -eq $false){
	Write-Host "Behavior Options specified, adding them to the command line"
	$AllArgs += "/b:$behaviorOptions"
}

if ([string]::IsNullOrWhiteSpace($excludeOptions) -eq $false){
	Write-Host "Exclude Options specified, adding them to the command line"
	$AllArgs += "/exc:$excludeOptions"
}

if ([string]::IsNullOrWhiteSpace($ignoreOptions) -eq $false){
	Write-Host "Ignore Options specified, adding them to the command line"
	$AllArgs += "/i:$ignoreOptions"
}

if ([string]::IsNullOrWhiteSpace($storageOptions) -eq $false){
	Write-Host "Storage Options specified, adding them to the command line"
	$AllArgs += "/g:$storageOptions"
}

if ($excludeDependencies -eq "True"){
	Write-Host "Exclude Dependencies set to true, adding them to the command line"
	$AllArgs += "/excludedependencies"
}

if ($includeIdentical -eq "True"){
	Write-Host "Include identical set to true, adding that to the command line"
    $AllArgs += "/includeidentical" 
}

if ([string]::IsNullOrWhiteSpace($filterPath) -eq $false){
	Write-Host "Custom Filter Path specified, adding them to the command line"
	$AllArgs += "/f:`"$sourceFolder\$filterPath`""
}

& "$schemaCompareExe" $AllArgs

$successful = $false
$upload = $false
if ($lastExitCode -eq 61){
	Write-Highlight "Changes found, the delta script location is: $changeScript"
    Write-Highlight "Uploading script and report as artifacts"
    
	$successful = $true
    $upload = $true
}

if ($lastExitCode -eq 0){
	Write-Highlight "No changes were detected"
	$successful = $true
}

Set-OctopusVariable -name "OracleRedgateCreateReleaseChangesFound" -value $upload

if ($upload){
  $environmentName = $OctopusParameters["Octopus.Environment.Name"]
  $artifactName = "$environmentName" + "Changes.html"
  New-OctopusArtifact -Path "$deltaReportPath" -Name "$artifactName"
  
  $scriptArtifactName = "$environmentName" + "Update.sql"
  New-OctopusArtifact -Path "$changeScript" -Name "$scriptArtifactName"    
}

Set-OctopusVariable -name "DatabaseChangesFound" -value $upload
  
if ($successful){  
  exit 0
}