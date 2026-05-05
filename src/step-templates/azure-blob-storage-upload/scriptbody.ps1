function Find-InstallLocations {
    $result = @()
    $OctopusParameters.Keys | foreach {
        if ($_.EndsWith('].Output.Package.InstallationDirectoryPath')) {
            $result += $OctopusParameters[$_]
        }
    }
    return $result
}

function Find-InstallLocation($stepName) {
    $result = $OctopusParameters.Keys | where {
        $_.Equals("Octopus.Action[$stepName].Output.Package.InstallationDirectoryPath",  [System.StringComparison]::OrdinalIgnoreCase)
    } | select -first 1
 
    if ($result) {
        return $OctopusParameters[$result]
    }
 
    throw "No install location found for step: $stepName"
}

function Find-SingleInstallLocation {
    $all = @(Find-InstallLocations)
    if ($all.Length -eq 1) {
        return $all[0]
    }
    if ($all.Length -eq 0) {
        throw "No package steps found"
    }
    throw "Multiple package steps have run; please specify a single step"
}

# Check if Windows Azure Powershell is avaiable 
try{ 
    Import-Module Azure -ErrorAction Stop
}catch{
    throw "Windows Azure Powershell not found! Please make sure to install them from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
}

Import-AzurePublishSettingsFile $PublishSettingsFile

# The script has been tested on Powershell 3.0
Set-StrictMode -Version 3

$stepPath = ""
if (-not [string]::IsNullOrEmpty($NugetPackageStepName)) {
    Write-Host "Finding path to package step: $NugetPackageStepName"
    $stepPath = Find-InstallLocation $NugetPackageStepName
} else {
    $stepPath = Find-SingleInstallLocation
}
Write-Host "Package was installed to: $stepPath"

$fullPath = "$stepPath\$CopyDirectory"
Write-Host "Copying Files in: $fullPath"

# Get a list of files from the project folder
$files = @(ls -Path $fullPath -File -Recurse)

$fileCount = $files.Count
Write-Host "Found $fileCount Files: $files"

$context = New-AzureStorageContext `
    -StorageAccountName $StorageAccount `
    -StorageAccountKey $StorageAccountKey

if ($files -ne $null -and $files.Count -gt 0)
{
    # Create the storage container.
    $existingContainer = Get-AzureStorageContainer -Context $context | 
        Where-Object { $_.Name -like $StorageContainer }

    if (-not $existingContainer)
    {
        $newContainer = New-AzureStorageContainer `
                            -Context $context `
                            -Name $StorageContainer `
                            -Permission Blob
        "Storage container '" + $newContainer.Name + "' created."
    }

    # Upload the files to storage container.
    $fileCount = $files.Count
    $time = [DateTime]::UtcNow
    if ($files.Count -gt 0)
    {
        foreach ($file in $files) 
        {
            $blobFileName = $file.FullName.Replace($fullPath, '').TrimStart('\')
            $contentType = switch ([System.IO.Path]::GetExtension($file))
	        {
	            ".css" {"text/css"}
	            ".js" {"text/javascript"}
	            ".json" {"application/json"}
	            ".html" {"text/html"}
	            ".png" {"image/png"}
	            ".svg" {"image/svg+xml"}
	            default {"application/octet-stream"}
	        }

            Set-AzureStorageBlobContent `
                -Container $StorageContainer `
                -Context $context `
                -File $file.FullName `
                -Blob $blobFileName `
                -Properties @{ContentType=$contentType} `
                -Force
        }
    }

    $duration = [DateTime]::UtcNow - $time

    "Uploaded " + $files.Count + " files to blob container '" + $StorageContainer + "'."
    "Total upload time: " + $duration.TotalMinutes + " minutes."
}
else
{
    Write-Warning "No files found."
}