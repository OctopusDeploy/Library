$sourceDirectoryPath = $OctopusParameters["CombineFiles.Directory.Source"]
$sourceDirectoryPackagePath = $OctopusParameters["CombineFiles.Directory.PackageSource"]
$sourceDirectoryFilter = $OctopusParameters["CombineFiles.Directory.Filter"]
$destinationFile = $OctopusParameters["CombineFiles.Destination.FileName"]
$createArtifact = $OctopusParameters["CombineFiles.Destination.CreateArtifact"]
$commentCharacters = $OctopusParameters["CombineFiles.Destination.CommentCharacters"]

if ([string]::IsNullOrWhiteSpace($sourceDirectoryPackagePath) -eq $false){
	Write-Host "A previous package path was specified, grabing that"
	$sourceDirectory = $OctopusParameters["Octopus.Action[$sourceDirectoryPackagePath].Output.Package.InstallationDirectoryPath"]
    $sourceDirectory = "$sourceDirectory\$sourceDirectoryPath"
}
else {
	$sourceDirectory = "$sourceDirectoryPath"
}

Write-Host "Source Directory: $sourceDirectory"
Write-Host "Source File Filter: $sourceDirectoryFilter"
Write-Host "Combined File Name: $destinationFile"
Write-Host "Create Artifact: $createArtifact"
Write-Host "Comment Characters: $commentCharacters"

if ([string]::IsNullOrWhiteSpace($sourceDirectory)){
	throw-exception "The source directory variable is required."
}

if ((Test-Path $sourceDirectory) -eq $false){
	Write-Host "The directory $sourceDirectory was not found, skipping"
	exit 0
}

if ((Test-Path $destinationFile) -eq $false){
	Write-Host "Creating the file: $destinationFile"
	New-Item -Path $destinationFile -ItemType "file"
}
else {
	Write-Host "The file $destinationFile already exists"
}

if ([string]::IsNullOrWhiteSpace($sourceDirectoryFilter)){
	Write-Host "Source directory filter not specified, grabbing all files"
	$filePath = "$sourceDirectory\*"
}
else {
	Write-Host "Source directory filter specified, grabbing filtered files"
	$filePath = "$sourceDirectory\*"
}

Write-Host "Getting child items using $filePath"
$filesToCombine = Get-ChildItem -Path $filePath -File | Sort-Object -Property Name

foreach ($file in $filesToCombine)
{
	Write-Host "Adding content to $changeScript from $file"

	if ([string]::IsNullOrWhiteSpace($commentCharacters) -eq $false){    
		Add-Content -Path $destinationFile -Value "$commentCharacters Contents from $file"
    }
    
	Add-Content -Path $destinationFile -Value (Get-Content $file)        
} 

if ($createArtifact -eq "True"){	 
  New-OctopusArtifact -Path "$destinationFile"
}