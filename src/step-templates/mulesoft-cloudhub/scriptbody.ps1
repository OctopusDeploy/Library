Function Get-NpmExecutable
{
	# Define parameters
    param (
    	$NodeVersion = "18.16.0"
    )
       
    # Declare local variables
    $npmDownloadUrl = "https://nodejs.org/dist/v$NodeVersion/"
    $downloadFileName = [string]::Empty
    $npmExecutable = [string]::Empty
    
    # Assign download url
    if ($IsWindows)
    {
    	$downloadFileName += "node-v$($NodeVersion)-win-x64.zip"
    }
    else
    {
    	$downloadFileName += "node-v$($NodeVersion)-linux-x64.tar.xz"
    }

	# Create folder for npm
    if ((Test-Path -Path "$PWD/npm") -eq $false)
    {
    	New-Item -Path "$PWD/npm" -ItemType "Directory"
    }
    
    # Download npm binary
    Write-Host "Downloading $(($npmDownloadUrl + $downloadFileName)) ..."
    Invoke-WebRequest -Uri ($npmDownloadUrl + $downloadFileName) -Outfile "$PWD/$downloadFileName"
    
    Write-Output "Extracting $downloadFileName ... "
    
    if ($IsWindows)
    {
      # Extract
      Expand-Archive -Path "$PWD/$downloadFileName" -DestinationPath "$PWD/npm"
      
      # Find the executable
      $npmExecutable = Get-ChildItem -Path "$PWD/npm/$($downloadFileName.Replace('.zip', ''))" | Where-Object {$_.Name -eq "npm.cmd"}
    }
    
    if ($IsLinux)
    {
      # Extract archive
      tar -xf "$PWD/$downloadFileName" --directory "$PWD/npm"
      
      # Find the executable
      $npmExecutable = Get-ChildItem -Path "$PWD/npm/$($downloadFileName.Replace('.tar.xz', ''))/bin" | Where-Object {$_.Name -eq "npm"}      
    }
    
    # Insert location of executable into PATH environment variable so it can be called from anywhere
    $env:PATH = "$($npmExecutable.Directory)$([IO.Path]::PathSeparator)" + $env:PATH
}

Function Install-MulesoftCLI
{
	# Define parameters
    param (
    	$CLIVersion = "4"
    )
	
    # Run npm command to install pluguin
    Write-Host "Installing anypoint-cli-v$($CLIVersion) node module ..."
    
    # Adjust install command based on operating system
    if ($IsWindows)
    {
    	& npm install -g "anypoint-cli-v$($CLIVersion)" "2>&1"
    }
    else
    {
    	& npm install -g "anypoint-cli-v$($CLIVersion)" 2>&1
    }
    
	# Check exit code
	if ($lastExitCode -ne 0)
	{
		# Fail the step
    	Write-Error "Installation failed!"
	}
}

Function Deploy-MulesoftApplication
{
	# Define parameters
    param (
    	$AssetFilePath,
        $ApplicationName,
        $RuntimeVersion,
        $NumberOfWorkers,
        $WorkerSize,
        $Region
    )
    
    # Replace path seperator
    if ($AssetFilePath.Contains("\"))
    {
    	# Replace them with forward slash
        $AssetFilePath = $AssetFilePath.Replace("\", "/")
    }
    
    # Check to see if application already exists
    $applicationList = (anypoint-cli-v4 runtime-mgr:cloudhub-application:list --output json | ConvertFrom-JSON)
    $deployResults = $null
    
    if ($null -eq ($applicationList | Where-Object {$_.domain -eq $ApplicationName}))
    {
    	# Deploy the application to cloud hub
        Write-Host "Deploying new application ..."
    	$deployResults = anypoint-cli-v4 runtime-mgr:cloudhub-application:deploy $ApplicationName $AssetFilePath --output json --runtime $RuntimeVersion --workers $NumberOfWorkers --workerSize $WorkerSize --region $Region
    }
    else
    {
    	# Update the application
        Write-Host "Updating existing application ..."
        $deployResults = anypoint-cli-v4 runtime-mgr:cloudhub-application:modify $ApplicationName $AssetFilePath --output json --runtime $RuntimeVersion --workers $NumberOfWorkers --workerSize $WorkerSize --region $Region
    }
    
    # Display results 
    Write-Host "Results:"
    $deployResults
}

# Check to see if $IsWindows is available
if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

if ($IsWindows)
{
	# Disable progress bar for faster installation
    $ProgressPreference = 'SilentlyContinue'
}

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Get parameters
$downloadUtils = [System.Convert]::ToBoolean("$($OctopusParameters['Mulesoft.Download'])")

# Check to see if we need to download utilities
if ($downloadUtils)
{
	Get-NpmExecutable -NodeVersion $OctopusParameters['Mulesoft.Node.CLI.Version']
	Install-MulesoftCLI -CLIVersion $OctopusParameters['Mulesoft.Anypoint.CLI.Version']
}

# Set environment variables
$env:ANYPOINT_CLIENT_ID = $OctopusParameters['Mulesoft.Anypoint.Client.Id']
$env:ANYPOINT_CLIENT_SECRET = $OctopusParameters['Mulesoft.Anypoint.Client.Secret']
$env:ANYPOINT_ORG = $OctopusParameters['Mulesoft.Anypoint.Organization.Id']
$env:ANYPOINT_ENV = $OctopusParameters['Mulesoft.Anypoint.Environment']

# Set global variables
$mulesoftOrganizationId = $OctopusParameters['Mulesoft.Anypoint.Organization.Id']
$mulesoftAssetVersionNumber = $OctopusParameters['Octopus.Action.Package[Mulesoft.Asset].PackageVersion']
$mulesoftAssetArtifactId = $OctopusParameters['Octopus.Action.Package[Mulesoft.Asset].PackageId']
$mulesoftApplicationName = $OctopusParameters['Mulesoft.Anypoint.Application.Name'].ToLower()
$mulesoftRuntimeVersion = $OctopusParameters['Mulesoft.Anypoint.Runtime.Version']
$mulesoftNumberOfWorkers = $OctopusParameters['Mulesfot.Anypoint.Worker.Count']
$mulesoftWorkerSize = $OctopusParameters['Mulesoft.Anypoint.Worker.Size']
$mulesoftRegion = $OctopusParameters['Mulesoft.Anypoint.Region']

# Check optional parameters
if ([string]::IsNullOrWhitespace($mulesoftNumberOfWorkers))
{
	$mulesoftNumberOfWorkers = "1"
}

if ([string]::IsNullOrWhitespace($mulesoftWorkerSize))
{
	$mulesoftWorkerSize = "1"
}

# Display variable values
Write-Host "================== Deploying to CloudHub with the following options =================="
Write-Host "Organization Id/Group Id: $mulesoftOrganizationId"
Write-Host "Artifact Id: $mulesoftAssetArtifactId"
Write-Host "Version number: $mulesoftAssetVersionNumber"
Write-Host "Application Name: $mulesoftApplicationname"
Write-Host "Environment: $($env:ANYPOINT_ENV)"
Write-Host "Runtime version: $mulesoftRuntimeVersion"
Write-Host "Number of workers: $mulesoftNumberOfWorkers"
Write-Host "Worker size: $mulesoftWorkerSize"
Write-Host "Region: $mulesoftRegion"
Write-Host "======================================================================================="

# Get file properties
$mulesoftApplicationFileExtension = [System.IO.Path]::GetExtension("$PWD/$($OctopusParameters['Octopus.Action.Package[Mulesoft.Asset].PackageFileName'])")

# Rename the file to the original
Rename-Item -Path "$PWD/$($OctopusParameters['Octopus.Action.Package[Mulesoft.Asset].PackageFileName'])" -NewName "$($mulesoftAssetArtifactId).$($mulesoftAssetVersionNumber)$mulesoftApplicationFileExtension"
$mulesoftApplicationFilePath = "$PWD/$($mulesoftAssetArtifactId).$($mulesoftAssetVersionNumber)$mulesoftApplicationFileExtension"

# Upload asset to exchange
Deploy-MulesoftApplication -AssetFilePath $mulesoftApplicationFilePath -ApplicationName $mulesoftApplicationName -Region $mulesoftRegion -RuntimeVersion $mulesoftRuntimeVersion -NumberOfWorkers $mulesoftNumberOfWorkers -Workersize $mulesoftWorkerSize

