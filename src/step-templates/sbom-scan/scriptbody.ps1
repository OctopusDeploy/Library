Write-Host "Pulling Trivy Docker Image"
Write-Host "##octopus[stdout-verbose]"
docker pull ghcr.io/aquasecurity/trivy
Write-Host "##octopus[stdout-default]"

$SUCCESS = 0

Write-Host "##octopus[stdout-verbose]"
Get-ChildItem -Path "." | Out-String
Write-Host "##octopus[stdout-default]"

# Find all bom.json files
$bomFiles = Get-ChildItem -Path "." -Filter "bom.json" -Recurse -File

if ($bomFiles.Count -eq 0) {
    Write-Host "No bom.json files found in the current directory."
    exit 0
}

foreach ($file in $bomFiles) {
    Write-Host "Scanning $($file.FullName)"

    # Delete any existing report file
    if (Test-Path "$($file.FullName)/depscan-bom.json") {
        Remove-Item "$($file.FullName)/depscan-bom.json" -Force
    }

    # Generate the report, capturing the output
    try {
        $OUTPUT = docker run --rm -v "$($file.FullName):/input/$($file.Name)" ghcr.io/aquasecurity/trivy sbom -q "/input/$($file.Name)"
        $exitCode = $LASTEXITCODE
    }
    catch {
        $OUTPUT = $_.Exception.Message
        $exitCode = 1
    }

    # Run again to generate the JSON output in the same directory as the bom.json file
    docker run --rm -v "$($file.DirectoryName):/output" -v "$($file.FullName):/input/$($file.Name)" ghcr.io/aquasecurity/trivy sbom -q -f json -o /output/depscan-bom.json "/input/$($file.Name)"

    # Parse JSON output to count vulnerabilities
    $jsonContent = Get-Content -Path "$($file.DirectoryName)/depscan-bom.json" | ConvertFrom-Json
    $CRITICAL = ($jsonContent.Results | ForEach-Object { $_.Vulnerabilities } | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $HIGH = ($jsonContent.Results | ForEach-Object { $_.Vulnerabilities } | Where-Object { $_.Severity -eq "HIGH" }).Count

    if ("#{Octopus.Environment.Name}" -eq "Security") {
        Write-Highlight "🟥 $CRITICAL critical vulnerabilities"
        Write-Highlight "🟧 $HIGH high vulnerabilities"
    }

    # Set success to 1 if exit code is not zero
    if ($exitCode -ne 0) {
        $SUCCESS = 1
    }

    # Print the output
    $OUTPUT | ForEach-Object {
        if ($_.Length -gt 0) {
            Write-Host $_
        }
    }
}

# Find all depscan-bom.json files recursively
$depscanFiles = Get-ChildItem -Path "." -Filter "depscan-bom.json" -Recurse -File

if ($depscanFiles.Count -gt 0) {
    $zipPath = "$PWD/depscan-bom.zip"

    # Remove existing zip if present
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # Create a temporary directory structure and copy files with relative paths
    $tempDir = "$PWD/temp_zip"

    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    foreach ($file in $depscanFiles) {
        $relativePath = $file.FullName.Substring($PWD.Path.Length + 1)
        $targetPath = Join-Path $tempDir $relativePath
        $targetDir = Split-Path $targetPath -Parent

        Write-Host "Adding $relativePath to zip"

        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        Copy-Item $file.FullName -Destination $targetPath
    }

    # Compress with relative paths
    Compress-Archive -Path "$tempDir/*" -DestinationPath $zipPath

    # Cleanup temp directory
    Remove-Item $tempDir -Recurse -Force

    # Octopus Deploy artifact
    New-OctopusArtifact $zipPath

} else {
    Write-Host "No depscan-bom.json files found to zip."
}

# Cleanup
for ($i = 1; $i -le 10; $i++) {
    try {
        if (Test-Path "bundle") {
            Set-ItemProperty -Path "bundle" -Name IsReadOnly -Value $false -Recurse -ErrorAction SilentlyContinue
            Remove-Item -Path "bundle" -Recurse -Force -ErrorAction Stop
            break
        }
    }
    catch {
        Write-Host "Attempting to clean up files"
        Start-Sleep -Seconds 1
    }
}

# Set Octopus variable
Set-OctopusVariable -Name "VerificationResult" -Value $SUCCESS

exit 0