$SourceDirectoryName = $OctopusParameters['SourceDirectoryName']
$DestinationArchiveFileName = $OctopusParameters['DestinationArchiveFileName']
$CompressionLevel = $OctopusParameters['CompressionLevel']
$IncludeBaseDirectory = $OctopusParameters['IncludeBaseDirectory']
$OverwriteDestination = $OctopusParameters['OverwriteDestination']

if (!$SourceDirectoryName)
{
    Write-Error "No Source Directory name was specified. Please specify the name of the directory to that will be zipped."
    exit -2
}

if (!$DestinationArchiveFileName)
{
    Write-Error "No Destination Archive File name was specified. Please specify the name of the zip file to be created."
    exit -2
}

if (($OverwriteDestination) -and (Test-Path $DestinationArchiveFileName))
{
    Write-Host "$DestinationArchiveFileName already exists. Will delete it before we create a new zip file with the same name."
    Remove-Item $DestinationArchiveFileName
}

Write-Host "Creating Zip file $DestinationArchiveFileName with the contents of directory $SourceDirectoryName using compression level $CompressionLevel"

$assembly = [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
[System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDirectoryName, $DestinationArchiveFileName, $CompressionLevel, $IncludeBaseDirectory)
