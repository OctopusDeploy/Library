$source = $OctopusParameters['Source']
$destination = $OctopusParameters['Destination']

if(Test-Path $destination)
{
    ## Clean the destination folder
    Write-Host "Cleaning $destination"
    Remove-Item $destination -Recurse
}

## Copy recursively
Write-Host "Copying from $source to $destination"
Copy-Item $source $destination -Recurse